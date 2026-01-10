import os
import json
from typing import Any

import mysql.connector
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.encoders import jsonable_encoder
from fastapi.responses import HTMLResponse, JSONResponse

load_dotenv()
DB_NAME = os.getenv("DB_NAME", "DEV_CCP")

app = FastAPI()


def get_conn():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=DB_NAME,
    )


def as_python_json(v: Any):
    """
    MySQL JSON puede llegar como:
      - dict/list (ya parseado)
      - str (JSON)
      - bytes
      - None
    """
    if v is None:
        return None
    if isinstance(v, (dict, list)):
        return v
    if isinstance(v, (bytes, bytearray)):
        v = v.decode("utf-8", errors="replace")
    if isinstance(v, str):
        try:
            return json.loads(v)
        except json.JSONDecodeError:
            return v
    return v


def fetch_latest_runs():
    conn = get_conn()
    try:
        cur = conn.cursor(dictionary=True)

        # Último run por pipeline
        cur.execute(
            """
            SELECT pr.*
            FROM pipeline_run pr
            JOIN (
              SELECT pipeline_id, MAX(run_ts) AS max_ts
              FROM pipeline_run
              GROUP BY pipeline_id
            ) t
              ON t.pipeline_id = pr.pipeline_id AND t.max_ts = pr.run_ts
            ORDER BY pr.pipeline_id
            """
        )
        rows = cur.fetchall()

        for r in rows:
            r["demand"] = as_python_json(r.get("demand_json"))
            r["result"] = as_python_json(r.get("result_json"))

        return rows
    finally:
        conn.close()


@app.get("/api/latest")
def api_latest():
    rows = fetch_latest_runs()
    # Esto arregla el 500: convierte Decimal/datetime a JSON válido
    return JSONResponse(content=jsonable_encoder(rows))


@app.get("/", response_class=HTMLResponse)
def home():
    html = """
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>CCP · Leontief</title>
  <style>
    :root{
      --bg:#0b0d10; --card:#11151b; --muted:#8a93a3; --fg:#e9edf5;
      --accent:#7c3aed; --line:#1f2630;
      --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      --sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial;
    }
    body{ margin:0; background:radial-gradient(1200px 800px at 20% 10%, rgba(124,58,237,.20), transparent 55%),
                         radial-gradient(900px 600px at 80% 30%, rgba(34,197,94,.10), transparent 60%),
                         var(--bg);
          color:var(--fg); font-family:var(--sans); }
    .wrap{ max-width:1100px; margin:0 auto; padding:28px 18px 60px; }
    .top{ display:flex; align-items:flex-end; justify-content:space-between; gap:12px; margin-bottom:18px; }
    h1{ font-size:18px; letter-spacing:.12em; text-transform:uppercase; margin:0; font-family:var(--mono); }
    .meta{ font-family:var(--mono); font-size:12px; color:var(--muted); }
    .grid{ display:grid; grid-template-columns: 1fr; gap:14px; }
    .card{ background:linear-gradient(180deg, rgba(255,255,255,.03), rgba(255,255,255,.00));
           border:1px solid var(--line); border-radius:16px; overflow:hidden; }
    .card-h{ display:flex; justify-content:space-between; gap:10px; padding:14px 14px 10px; border-bottom:1px solid var(--line); }
    .pill{ font-family:var(--mono); font-size:12px; padding:6px 10px; border-radius:999px; background:rgba(124,58,237,.12); border:1px solid rgba(124,58,237,.35); }
    .btn{ font-family:var(--mono); font-size:12px; color:var(--fg); background:transparent;
          border:1px solid var(--line); border-radius:10px; padding:8px 10px; cursor:pointer; }
    .btn:hover{ border-color:rgba(124,58,237,.6); }
    table{ width:100%; border-collapse:collapse; font-family:var(--mono); font-size:12px; }
    th,td{ padding:10px 12px; border-bottom:1px solid var(--line); vertical-align:top; }
    th{ text-align:left; color:#c7cfdd; font-weight:600; }
    td{ color:#d7deea; }
    .muted{ color:var(--muted); }
    .right{ text-align:right; }
    .tot{ font-weight:700; }
    .foot{ margin-top:18px; color:var(--muted); font-family:var(--mono); font-size:12px; }
    .err{ padding:12px; color:#ffd0d0; font-family:var(--mono); font-size:12px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="top">
      <div>
        <h1>CCP · Leontief</h1>
        <div class="meta" id="updated">Cargando…</div>
      </div>
      <button class="btn" onclick="loadData()">refrescar</button>
    </div>

    <div class="grid" id="content"></div>

    <div class="foot">
      Auto-actualización: cada 60 minutos · Endpoint: <span class="muted">/api/latest</span>
    </div>
  </div>

<script>
function num(x){
  const n = (x === null || x === undefined) ? 0 : Number(x);
  return Number.isFinite(n) ? n : 0;
}

async function loadData(){
  const root = document.getElementById('content');
  try{
    const res = await fetch('/api/latest', {cache:'no-store'});
    if(!res.ok){
      const txt = await res.text();
      throw new Error(`HTTP ${res.status}: ${txt}`);
    }
    const data = await res.json();

    document.getElementById('updated').textContent =
      `Última carga web: ${new Date().toLocaleString()}`;

    root.innerHTML = '';

    if(!data.length){
      root.innerHTML = '<div class="card"><div class="card-h"><div class="pill">Sin datos</div></div><div class="err">No hay ejecuciones en pipeline_run.</div></div>';
      return;
    }

    for(const run of data){
      const demand = run.demand || {};
      const demandPairs = Object.entries(demand).map(([k,v]) => `${k}=${v}`).join(' · ');

      const rows = run.result || [];
      const bodyRows = rows.map(r => `
        <tr class="${r.sku === 'TOTAL' ? 'tot' : ''}">
          <td>${r.sku ?? ''}</td>
          <td class="right">${num(r.demanda_d).toFixed(0)}</td>
          <td class="right">${num(r.produccion_total_x).toFixed(0)}</td>
          <td class="right">${num(r.horas_por_unidad).toFixed(6)}</td>
          <td class="right">${num(r.horas_totales).toFixed(3)}</td>
          <td class="right">${num(r.trabajadores_equivalentes).toFixed(3)}</td>
        </tr>
      `).join('');

      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <div class="card-h">
          <div class="pill">pipeline ${run.pipeline_id} · ${run.run_ts}</div>
          <div class="muted">hours=${run.horas_por_trabajador} · strict=${run.strict_missing_labor}</div>
        </div>
        <div style="padding:10px 12px" class="muted">${demandPairs}</div>
        <table>
          <thead>
            <tr>
              <th>sku</th>
              <th class="right">demanda</th>
              <th class="right">producción</th>
              <th class="right">h/u</th>
              <th class="right">horas</th>
              <th class="right">FTE</th>
            </tr>
          </thead>
          <tbody>${bodyRows}</tbody>
        </table>
      `;
      root.appendChild(card);
    }
  } catch(err){
    document.getElementById('updated').textContent = 'Error cargando datos';
    root.innerHTML = `<div class="card"><div class="card-h"><div class="pill">Error</div></div><div class="err">${String(err)}</div></div>`;
  }
}

loadData();
setInterval(loadData, 60 * 60 * 1000);
</script>
</body>
</html>
    """
    return HTMLResponse(html)
