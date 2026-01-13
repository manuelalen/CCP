"""
scripts/run_pipelines.py

Ejecuta pipelines configurados en MySQL (pipeline_config + pipeline_demand_item),
lanza el cálculo Leontief (compute_leontief_workers) y guarda resultados en pipeline_run.

Arreglos incluidos:
- Hace sys.path hack para que funcione con: python scripts/run_pipelines.py
- Convierte NaN/Inf a null antes de guardar JSON en MySQL (MySQL no acepta NaN en JSON)
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
import mysql.connector
from dotenv import load_dotenv

# ------------------------------------------------------------
# 1) Asegurar imports aunque ejecutes "python scripts/run_pipelines.py"
# ------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[1]  # .../CCP
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.pl_leontief import compute_leontief_workers  # noqa: E402

# ------------------------------------------------------------
# 2) Config env / MySQL
# ------------------------------------------------------------
load_dotenv()
DB_NAME = os.getenv("DB_NAME", "DEV_CCP")


def get_conn():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=DB_NAME,
    )


# ------------------------------------------------------------
# 3) Query helpers
# ------------------------------------------------------------
def fetch_active_pipelines(cur) -> List[Tuple[int, str, float, int]]:
    """
    Returns: [(pipeline_id, pipeline_name, horas_por_trabajador, strict_missing_labor_int)]
    """
    cur.execute(
        """
        SELECT pipeline_id, pipeline_name, horas_por_trabajador, strict_missing_labor
        FROM pipeline_config
        WHERE is_active = 1
        ORDER BY pipeline_id
        """
    )
    return cur.fetchall()


def fetch_demand_for_pipeline(cur, pipeline_id: int) -> Dict[str, float]:
    cur.execute(
        """
        SELECT sku, cantidad
        FROM pipeline_demand_item
        WHERE pipeline_id = %s AND is_active = 1
        ORDER BY sku
        """,
        (pipeline_id,),
    )
    return {sku: float(qty) for (sku, qty) in cur.fetchall()}


def _json_safe(obj):
    """
    Convierte NaN/Inf y tipos numpy a valores JSON válidos.
    - NaN/Inf -> None (null)
    - numpy scalars -> python scalars
    """
    if obj is None:
        return None

    # numpy scalar -> python scalar
    if isinstance(obj, (np.integer, np.int64, np.int32)):
        return int(obj)
    if isinstance(obj, (np.floating, np.float64, np.float32)):
        val = float(obj)
        if np.isnan(val) or np.isinf(val):
            return None
        return val

    # float normal
    if isinstance(obj, float):
        if np.isnan(obj) or np.isinf(obj):
            return None
        return obj

    return obj


def dataframe_to_json_records(df: pd.DataFrame) -> str:
    """
    Devuelve un JSON (string) válido para MySQL JSON.
    Sustituye NaN/Inf por null.
    """
    df2 = df.replace([np.inf, -np.inf], np.nan).where(pd.notnull(df), None)
    records = df2.to_dict(orient="records")

    # Pasa por _json_safe en cada valor
    safe_records = []
    for r in records:
        safe_records.append({k: _json_safe(v) for k, v in r.items()})

    # allow_nan=False fuerza error si quedase algún NaN (así lo detectas)
    return json.dumps(safe_records, ensure_ascii=False, allow_nan=False)


def demand_to_json(demand: Dict[str, float]) -> str:
    safe_demand = {k: _json_safe(v) for k, v in demand.items()}
    return json.dumps(safe_demand, ensure_ascii=False, allow_nan=False)


def store_run(
    cur,
    pipeline_id: int,
    horas_por_trabajador: float,
    strict_missing_labor: bool,
    demand: Dict[str, float],
    df: pd.DataFrame,
) -> None:
    """
    Guarda el DF como JSON y también totales.
    """
    # Totales: si existe fila TOTAL la usamos; si no sumamos
    total_row = df[df["sku"] == "TOTAL"]
    if not total_row.empty:
        total_hours = float(total_row["horas_totales"].iloc[0])
        total_workers = float(total_row["trabajadores_equivalentes"].iloc[0])
    else:
        total_hours = float(df["horas_totales"].sum())
        total_workers = float(df["trabajadores_equivalentes"].sum())

    demand_json = demand_to_json(demand)
    result_json = dataframe_to_json_records(df)

    # OJO: No hace falta CAST(... AS JSON), MySQL valida el JSON al insertar en columna JSON.
    cur.execute(
        """
        INSERT INTO pipeline_run
          (pipeline_id, horas_por_trabajador, strict_missing_labor, demand_json, result_json, total_hours, total_workers_equivalent)
        VALUES
          (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            pipeline_id,
            float(horas_por_trabajador),
            int(bool(strict_missing_labor)),
            demand_json,
            result_json,
            total_hours,
            total_workers,
        ),
    )


# ------------------------------------------------------------
# 4) Runner
# ------------------------------------------------------------
def run_all() -> None:
    conn = get_conn()
    try:
        cur = conn.cursor()

        pipelines = fetch_active_pipelines(cur)
        if not pipelines:
            print("[INFO] No hay pipelines activos en pipeline_config.")
            return

        for pipeline_id, pipeline_name, horas, strict_int in pipelines:
            if pipeline_name != "pl_leontief":
                print(f"[WARN] Pipeline '{pipeline_name}' no soportado (solo 'pl_leontief'). Se omite.")
                continue

            demand = fetch_demand_for_pipeline(cur, pipeline_id)
            if not demand:
                print(f"[WARN] pipeline_id={pipeline_id} no tiene demanda activa. Se omite.")
                continue

            strict = bool(strict_int)

            print(
                f"[INFO] Ejecutando pipeline_id={pipeline_id} name={pipeline_name} "
                f"horas={float(horas)} strict={strict} demand={demand}"
            )

            df = compute_leontief_workers(
                demand=demand,
                horas_por_trabajador_periodo=float(horas),
                strict_missing_labor=strict,
            )

            store_run(
                cur=cur,
                pipeline_id=pipeline_id,
                horas_por_trabajador=float(horas),
                strict_missing_labor=strict,
                demand=demand,
                df=df,
            )
            conn.commit()
            print(f"[OK] Guardado resultado pipeline_id={pipeline_id} en pipeline_run.")

    finally:
        conn.close()


if __name__ == "__main__":
    run_all()
