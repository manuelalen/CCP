#!/usr/bin/env python3
"""
pl_runner.py

Pipeline runner basado en:
- DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS (requirements)
- DEV_CCP.T_METADATA (metadata)

Reglas:
- datasource = 'file'
    Inserta datos del fichero en tabla TARGET de metadata
    (ACTIVE=1 y INGESTION_NAME = la indicada por el usuario)

- datasource = 'mysql'
    - task_type = 'Extraction Data'
        Exporta CSV en ./extracciones/ con nombre:
        {task_id}_{task_title}_{YYYYMMDD}.csv

    - task_type = 'View Creation'
        Crea/Reemplaza VIEW en el TARGET de metadata (ACTIVE=1 e INGESTION_NAME indicada),
        usando el SELECT construido a partir de los JSON de requirements (igual que extracción).

    - otro
        Mensaje de revisión

Requisitos:
python -m pip install pandas mysql-connector-python python-dotenv
"""

import os
import re
import json
import argparse
from datetime import datetime

import pandas as pd
import mysql.connector
from mysql.connector import Error

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass


# -----------------------------
# Config
# -----------------------------
DB_HOST = os.getenv("MYSQL_HOST", "localhost")
DB_PORT = int(os.getenv("MYSQL_PORT", "3306"))
DB_USER = os.getenv("MYSQL_USER", "root")
DB_PASS = os.getenv("MYSQL_PASSWORD", "")
DB_DEFAULT = os.getenv("MYSQL_DATABASE", "mysql")

REQ_TABLE = os.getenv("REQ_TABLE", "DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS")
META_TABLE = os.getenv("META_TABLE", "DEV_CCP.T_METADATA")

EXTRACTIONS_DIR = os.path.join(os.getcwd(), "extracciones")


# ------------------------------
# Helpers
# ------------------------------
def slugify_filename(text: str, max_len: int = 80) -> str:
    text = (text or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text[:max_len] if len(text) > max_len else text


def mysql_connect():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASS,
        database=DB_DEFAULT,
        autocommit=False,
    )


def fetch_one_dict(cur, query: str, params=None):
    cur.execute(query, params or ())
    row = cur.fetchone()
    if row is None:
        return None
    cols = [d[0] for d in cur.description]
    return dict(zip(cols, row))


def fetch_all_dict(cur, query: str, params=None):
    cur.execute(query, params or ())
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in rows]


def read_requirement(conn, task_id: str) -> dict:
    q = f"""
        SELECT
            task_id, task_title, task_description, project_id, task_type,
            datasource, file_name, file_columns_name,
            tablename, tablecolumns, join_type, task_active
        FROM {REQ_TABLE}
        WHERE task_id = %s
        LIMIT 1
    """
    cur = conn.cursor()
    req = fetch_one_dict(cur, q, (task_id,))
    cur.close()
    if not req:
        raise ValueError(f"No existe task_id={task_id} en {REQ_TABLE}")

    req["datasource"] = (req.get("datasource") or "").strip().lower()
    req["task_type"] = (req.get("task_type") or "").strip().lower()
    req["task_active"] = bool(req.get("task_active", 0))
    return req


def read_metadata(conn, ingestion_name: str):
    q = f"""
        SELECT *
        FROM {META_TABLE}
        WHERE ACTIVE = 1
          AND INGESTION_NAME = %s
        LIMIT 50
    """
    cur = conn.cursor()
    rows = fetch_all_dict(cur, q, (ingestion_name,))
    cur.close()
    return rows


def parse_target(target_value):
    """
    TARGET puede venir como:
      - string "db.table"
      - JSON string '{"database":"DEV_DPF","table":"DIM_FACTORIES"}'
      - dict {"database":"DEV_DPF","table":"DIM_FACTORIES"}
    Retorna: (database, table_or_view)
    """
    if target_value is None:
        return None, None

    if isinstance(target_value, (bytes, bytearray)):
        target_value = target_value.decode("utf-8")

    if isinstance(target_value, dict):
        return target_value.get("database"), target_value.get("table")

    if isinstance(target_value, str):
        s = target_value.strip()

        # JSON
        if s.startswith("{") and s.endswith("}"):
            obj = json.loads(s)
            return obj.get("database"), obj.get("table")

        # db.table
        if "." in s:
            db_name, table_name = s.split(".", 1)
            return db_name, table_name

        # solo nombre
        return DB_DEFAULT, s

    raise ValueError(f"Formato TARGET no soportado: {type(target_value)}")


def _decode_json_field(v):
    if isinstance(v, (bytes, bytearray)):
        v = v.decode("utf-8")
    if isinstance(v, str):
        return json.loads(v)
    return v


def infer_table_aliases(tablenames):
    out = []
    base_to_alias = {}
    for i, fqn in enumerate(tablenames, start=1):
        base = fqn.split(".")[-1]
        alias = f"t{i}"
        out.append((fqn, base, alias))
        base_to_alias[base] = alias
    return out, base_to_alias


def build_extraction_sql(req: dict) -> str:
    """
    Construye un SELECT con JOINs a partir de:
      - tablename (JSON array de FQNs)
      - tablecolumns (JSON array [{table, columns:[...]}])
      - join_type (JSON array de joins [{left,right,type,on:[[k1,k1],[k2,k2]]}])
    """
    tablenames = _decode_json_field(req.get("tablename"))
    tablecolumns = _decode_json_field(req.get("tablecolumns"))
    joins = _decode_json_field(req.get("join_type"))

    if joins is None:
        joins = []

    if not tablenames or not isinstance(tablenames, list):
        raise ValueError("tablename (JSON) debe ser un array no vacío de tablas FQN")
    if not tablecolumns or not isinstance(tablecolumns, list):
        raise ValueError("tablecolumns (JSON) debe ser un array no vacío con tablas y columnas")

    tables_info, base_to_alias = infer_table_aliases(tablenames)

    # SELECT columns
    select_parts = []
    for tc in tablecolumns:
        table_name = tc.get("table")
        cols = tc.get("columns", [])
        if not table_name or not cols:
            continue

        alias = base_to_alias.get(table_name) or base_to_alias.get(table_name.split(".")[-1])
        if not alias:
            raise ValueError(
                f"No encuentro alias para tablecolumns.table={table_name}. "
                f"Asegúrate de que coincide con el nombre base en tablename."
            )

        for c in cols:
            out_alias = f"{table_name}_{c}".replace(".", "_")
            select_parts.append(f"{alias}.`{c}` AS `{out_alias}`")

    if not select_parts:
        raise ValueError("No hay columnas en tablecolumns para seleccionar.")

    # FROM base = primera tabla
    base_fqn, _, base_alias = tables_info[0]
    sql = "SELECT\n  " + ",\n  ".join(select_parts) + f"\nFROM {base_fqn} {base_alias}\n"

    # JOINs
    for j in joins:
        left = j.get("left")
        right = j.get("right")
        jtype = (j.get("type") or "LEFT").strip().upper()
        on_pairs = j.get("on", [])

        left_alias = base_to_alias.get(left) or base_to_alias.get((left or "").split(".")[-1])
        right_alias = base_to_alias.get(right) or base_to_alias.get((right or "").split(".")[-1])

        right_base = (right or "").split(".")[-1]
        right_fqn = None
        for fqn, bname, alias in tables_info:
            if bname == right or bname == right_base:
                if alias == right_alias:
                    right_fqn = fqn
                    break
        if not right_fqn:
            for fqn, bname, _alias in tables_info:
                if bname == right_base:
                    right_fqn = fqn
                    break

        if not left_alias or not right_alias or not right_fqn:
            raise ValueError(f"Join inválido: {j}")
        if not on_pairs:
            raise ValueError(f"Join sin condición 'on': {j}")

        on_exprs = []
        for pair in on_pairs:
            if not isinstance(pair, (list, tuple)) or len(pair) != 2:
                raise ValueError(f"Par ON inválido: {pair}")
            lcol, rcol = pair
            on_exprs.append(f"{left_alias}.`{lcol}` = {right_alias}.`{rcol}`")

        sql += f"{jtype} JOIN {right_fqn} {right_alias} ON " + " AND ".join(on_exprs) + "\n"

    return sql.strip().rstrip(";")  # <- sin ; para reutilizar en VIEW


def sanitize_sql_for_view(sql: str) -> str:
    """
    Evita errores típicos al crear vistas:
    - multi-statement (solo permitimos 1 statement)
    - doble SELECT (SELECT SELECT ...)
    - BOM y caracteres raros
    """
    sql = (sql or "").replace("\ufeff", "").strip()

    # si llega más de un statement, nos quedamos con el primero
    if ";" in sql:
        sql = sql.split(";", 1)[0].strip()

    # caso "SELECT SELECT ..."
    sql = re.sub(r"^\s*SELECT\s+SELECT\s+", "SELECT ", sql, flags=re.IGNORECASE)

    return sql


def export_mysql_extraction_to_csv(conn, req: dict):
    os.makedirs(EXTRACTIONS_DIR, exist_ok=True)

    sql = build_extraction_sql(req)
    df = pd.read_sql(sql, conn)

    today = datetime.now().strftime("%Y%m%d")
    title_part = slugify_filename(req.get("task_title") or "task")
    fname = f"{req['task_id']}_{title_part}_{today}.csv"
    fpath = os.path.join(EXTRACTIONS_DIR, fname)

    df.to_csv(fpath, index=False, encoding="utf-8")
    print(f"[OK] Exportado CSV: {fpath}")
    print(f"[INFO] Filas: {len(df)}")
    return fpath


def ingest_file_to_mysql(conn, ingestion_name: str, fallback_file_path: str = None):
    meta_rows = read_metadata(conn, ingestion_name)
    if not meta_rows:
        raise ValueError(f"No hay metadata activa en {META_TABLE} para INGESTION_NAME='{ingestion_name}'")

    for row in meta_rows:
        target_raw = row.get("TARGET") or row.get("target")
        db_name, table_name = parse_target(target_raw)
        if not db_name or not table_name:
            raise ValueError("No puedo parsear TARGET para inserción. Esperaba db.table o JSON database/table.")

        source_path = (
            row.get("SOURCE") or row.get("source") or
            row.get("SOURCE_PATH") or row.get("source_path") or
            fallback_file_path
        )
        if not source_path:
            raise ValueError("No hay SOURCE/SOURCE_PATH en metadata ni file_name en requirements para cargar fichero")

        if not os.path.exists(source_path):
            raise ValueError(f"El fichero no existe: {source_path}")

        df = pd.read_csv(source_path)

        cur = conn.cursor()
        cur.execute(f"USE `{db_name}`;")
        conn.commit()
        cur.close()

        cols = list(df.columns)
        placeholders = ", ".join(["%s"] * len(cols))
        col_list = ", ".join([f"`{c}`" for c in cols])
        insert_sql = f"INSERT INTO `{table_name}` ({col_list}) VALUES ({placeholders})"

        data = [tuple(x) for x in df.itertuples(index=False, name=None)]

        cur = conn.cursor()
        cur.executemany(insert_sql, data)
        conn.commit()
        cur.close()

        print(f"[OK] Cargado fichero '{source_path}' -> {db_name}.{table_name} (rows={len(df)})")


def debug_show_create_view(conn, db_name: str, view_name: str):
    """
    Imprime la definición real de la vista, útil para depurar el error 1064 en SELECT.
    """
    cur = conn.cursor()
    cur.execute(f"SHOW CREATE VIEW `{db_name}`.`{view_name}`;")
    row = cur.fetchone()
    cur.close()
    if not row:
        print("[DEBUG] No se pudo obtener SHOW CREATE VIEW.")
        return
    # row[0]=View, row[1]=Create View...
    print("\n[DEBUG] SHOW CREATE VIEW:")
    print(row[1])
    print("")


def create_view_from_requirements(conn, req: dict, ingestion_name: str, debug: bool = False):
    """
    Crea/Reemplaza view usando:
      - TARGET de metadata (ACTIVE=1, INGESTION_NAME = user)
      - SELECT generado desde requirements (igual que extracción)
    """
    meta_rows = read_metadata(conn, ingestion_name)
    if not meta_rows:
        raise ValueError(f"No hay metadata activa en {META_TABLE} para INGESTION_NAME='{ingestion_name}'")

    chosen = meta_rows[0]
    target_raw = chosen.get("TARGET") or chosen.get("target")
    db_name, view_name = parse_target(target_raw)

    if not db_name or not view_name:
        raise ValueError("No puedo parsear TARGET. Esperaba db.table o JSON con database/table.")

    select_sql = build_extraction_sql(req)
    select_sql = sanitize_sql_for_view(select_sql)

    ddl = f"CREATE OR REPLACE VIEW `{db_name}`.`{view_name}` AS {select_sql};"

    if debug:
        print("\n[DEBUG] DDL que voy a ejecutar:\n")
        print(ddl)
        print("")

    cur = conn.cursor()
    cur.execute(ddl)
    conn.commit()
    cur.close()

    print(f"[OK] Vista creada/reemplazada: {db_name}.{view_name}")

    if debug:
        debug_show_create_view(conn, db_name, view_name)


# -----------------------------
# Main runner
# -----------------------------
def main():
    parser = argparse.ArgumentParser(description="Pipeline runner basado en DIM_TASK_REQUIREMENTS + T_METADATA")
    parser.add_argument("--task-id", required=True, help="Task ID (ej: WON-001)")
    parser.add_argument("--ingestion-name", required=False, help="INGESTION_NAME para buscar en DEV_CCP.T_METADATA")
    parser.add_argument("--debug", action="store_true", help="Imprime el DDL y el SHOW CREATE VIEW")
    args = parser.parse_args()

    conn = None
    try:
        conn = mysql_connect()
        req = read_requirement(conn, args.task_id)

        if not req["task_active"]:
            print(f"[STOP] task_id={args.task_id} está inactiva (task_active=0). No hago nada.")
            return

        ds = req["datasource"]
        tt = req["task_type"]

        if ds == "file":
            if not args.ingestion_name:
                raise ValueError("Para datasource=file necesitas --ingestion-name")
            ingest_file_to_mysql(conn, args.ingestion_name, fallback_file_path=req.get("file_name"))

        elif ds == "mysql":
            if tt == "extraction data":
                export_mysql_extraction_to_csv(conn, req)

            elif tt == "view creation":
                if not args.ingestion_name:
                    raise ValueError("Para task_type=View Creation necesitas --ingestion-name")
                create_view_from_requirements(conn, req, args.ingestion_name, debug=args.debug)

            else:
                print("[WARN] No se ha podido realizar ninguna acción.")
                print("       Revisa DIM_TASK_REQUIREMENTS: datasource='MySQL' pero task_type no es 'Extraction Data' ni 'View Creation'.")

        else:
            print("[WARN] No se ha podido realizar ninguna acción.")
            print("       Revisa DIM_TASK_REQUIREMENTS: datasource debe ser 'file' o 'MySQL'.")

    except Error as e:
        if conn:
            conn.rollback()
        print(f"[ERROR][MySQL] {e}")

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"[ERROR] {e}")

    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    main()
