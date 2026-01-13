"""
pl_leontief.py

Calcula producción total x usando el modelo de Leontief:
    x = (I - A)^(-1) d

y estima horas de trabajo y trabajadores equivalentes a partir de una tabla MySQL
tiempo_trabajo (horas por unidad, por rama/etapa, sumadas por SKU).

Ejecución:
  python pl_leontief.py --demand MEAL_RICE_CHICKEN_CURRY_400G=200000 TSHIRT_BASIC_M=100000 --hours 160

Variables de entorno (recomendado en .env):
  DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
"""

from __future__ import annotations

import argparse
import os
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

DB_NAME = os.getenv("DB_NAME", "DEV_CCP")


# ------------------------------------------------------------
# MySQL helpers
# ------------------------------------------------------------
def get_conn():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=DB_NAME,
    )


def table_exists(cur, table_name: str) -> bool:
    cur.execute(
        """
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        """,
        (DB_NAME, table_name),
    )
    return cur.fetchone()[0] > 0


def load_products(cur) -> List[str]:
    cur.execute("SELECT sku FROM product ORDER BY sku")
    return [r[0] for r in cur.fetchall()]


def load_labor_hours_per_unit(cur, skus: List[str]) -> pd.Series:
    """
    Serie indexada por SKU con horas_por_unidad totales (sumando ramas activas).
    Si falta un SKU, se devuelve 0.0 y se avisa.
    """
    if not table_exists(cur, "tiempo_trabajo"):
        raise RuntimeError("No existe la tabla tiempo_trabajo. Créala primero.")

    cur.execute(
        """
        SELECT sku, SUM(horas_por_unidad) AS horas_unit
        FROM tiempo_trabajo
        WHERE is_activo = 1
          AND vigente_desde <= CURDATE()
          AND (vigente_hasta IS NULL OR vigente_hasta >= CURDATE())
        GROUP BY sku
        """
    )
    data = dict(cur.fetchall())
    s = pd.Series({sku: float(data.get(sku, 0.0)) for sku in skus}, dtype="float64")

    missing = [sku for sku in skus if s[sku] == 0.0]
    if missing:
        print(
            "[WARN] SKUs sin tiempo_trabajo activo (horas_por_unidad=0):",
            missing[:20],
            ("..." if len(missing) > 20 else ""),
        )
    return s


def load_A_matrix(cur, skus: List[str]) -> np.ndarray:
    """
    Matriz técnica A de Leontief:
      A[i, j] = cantidad de input_sku (fila i) necesaria por unidad de output_sku (columna j)
    Se carga desde io_coef si existe; si no existe, A=0.
    """
    n = len(skus)
    idx = {sku: i for i, sku in enumerate(skus)}
    A = np.zeros((n, n), dtype="float64")

    if not table_exists(cur, "io_coef"):
        print("[INFO] No existe tabla io_coef -> usando A=0 (sin encadenamientos intermedios).")
        return A

    cur.execute(
        """
        SELECT input_sku, output_sku, qty_per_unit
        FROM io_coef
        WHERE is_active = 1
        """
    )
    rows = cur.fetchall()

    skipped = 0
    for input_sku, output_sku, qty in rows:
        if input_sku not in idx or output_sku not in idx:
            skipped += 1
            continue
        i = idx[input_sku]
        j = idx[output_sku]
        A[i, j] = float(qty)

    if skipped:
        print(f"[WARN] Se omitieron {skipped} filas io_coef porque input_sku/output_sku no existen en product.")
    return A


# ------------------------------------------------------------
# Core logic
# ------------------------------------------------------------
def compute_leontief_workers(
    demand: Dict[str, float],
    horas_por_trabajador_periodo: float = 160.0,
    strict_missing_labor: bool = False,
) -> pd.DataFrame:
    """
    demand: dict {sku: cantidad demandada} (demanda final)
    horas_por_trabajador_periodo: p.ej. 160h/mes o 40h/semana
    strict_missing_labor: si True, falla si hay SKUs con producción>0 y horas_por_unidad=0
    """
    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()

        # 1) SKUs (ramas)
        skus = load_products(cur)
        if not skus:
            raise RuntimeError("No hay productos en la tabla product.")

        idx = {sku: i for i, sku in enumerate(skus)}
        n = len(skus)

        # 2) Vector demanda d
        d = np.zeros((n,), dtype="float64")
        unknown: List[str] = []
        for sku, qty in demand.items():
            if sku not in idx:
                unknown.append(sku)
                continue
            d[idx[sku]] = float(qty)

        if unknown:
            raise ValueError(f"SKUs en demanda que no existen en product: {unknown}")

        # 3) Matriz A
        A = load_A_matrix(cur, skus)

        # 4) Leontief: x = (I - A)^-1 d
        I = np.eye(n, dtype="float64")
        M = I - A
        try:
            x = np.linalg.solve(M, d)
        except np.linalg.LinAlgError as e:
            raise RuntimeError("La matriz (I-A) es singular/no invertible. Revisa io_coef.") from e

        # 5) Horas por unidad
        labor_hours_unit = load_labor_hours_per_unit(cur, skus).to_numpy()

        if strict_missing_labor:
            missing_for_positive_x = [skus[i] for i in range(n) if x[i] > 0 and labor_hours_unit[i] == 0.0]
            if missing_for_positive_x:
                raise RuntimeError(
                    "Faltan tiempos de trabajo (horas_por_unidad=0) para SKUs con producción>0: "
                    + ", ".join(missing_for_positive_x)
                )

        labor_hours_total_by_sku = labor_hours_unit * x

        # 6) Trabajadores equivalentes
        h = float(horas_por_trabajador_periodo)
        workers_by_sku = labor_hours_total_by_sku / h
        total_hours = float(labor_hours_total_by_sku.sum())
        total_workers = total_hours / h

        # 7) Resultado
        df = pd.DataFrame(
            {
                "sku": skus,
                "demanda_d": d,
                "produccion_total_x": x,
                "horas_por_unidad": labor_hours_unit,
                "horas_totales": labor_hours_total_by_sku,
                "trabajadores_equivalentes": workers_by_sku,
            }
        )

        # Filtra irrelevantes
        df = df[(df["demanda_d"] != 0) | (df["produccion_total_x"] != 0)]

        # Totales
        totals = pd.DataFrame(
            [
                {
                    "sku": "TOTAL",
                    "demanda_d": float(df["demanda_d"].sum()),
                    "produccion_total_x": float(df["produccion_total_x"].sum()),
                    "horas_por_unidad": np.nan,
                    "horas_totales": total_hours,
                    "trabajadores_equivalentes": total_workers,
                }
            ]
        )
        df = pd.concat([df, totals], ignore_index=True)

        return df.sort_values(by=["sku"], kind="stable").reset_index(drop=True)

    finally:
        if conn:
            conn.close()


# ------------------------------------------------------------
# CLI
# ------------------------------------------------------------
def parse_demand(pairs: List[str]) -> Dict[str, float]:
    """
    Convierte ["SKU=100", "SKU2=50.5"] -> {"SKU":100.0,"SKU2":50.5}
    Acepta comas decimales: "50,5"
    """
    demand: Dict[str, float] = {}
    for p in pairs:
        if "=" not in p:
            raise ValueError(f"Formato inválido '{p}'. Usa SKU=NUM")
        sku, qty = p.split("=", 1)
        sku = sku.strip()
        qty = qty.strip().replace(",", ".")
        if not sku:
            raise ValueError(f"SKU vacío en '{p}'")
        demand[sku] = float(qty)
    return demand


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Leontief + cálculo de trabajadores desde MySQL")
    ap.add_argument(
        "--demand",
        nargs="+",
        required=True,
        help="Demanda como pares SKU=NUM. Ej: --demand MEAL_RICE_CHICKEN_CURRY_400G=10000",
    )
    ap.add_argument(
        "--hours",
        type=float,
        default=160.0,
        help="Horas por trabajador en el periodo (default 160)",
    )
    ap.add_argument(
        "--strict-missing-labor",
        action="store_true",
        help="Si se activa, falla si falta tiempo_trabajo para algún SKU con producción>0",
    )
    args = ap.parse_args(argv)

    demanda = parse_demand(args.demand)

    df = compute_leontief_workers(
        demand=demanda,
        horas_por_trabajador_periodo=args.hours,
        strict_missing_labor=args.strict_missing_labor,
    )

    # imprime sin índice
    print(df.to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
