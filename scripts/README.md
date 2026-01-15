# CCP — Configurable Control Pipeline (local-first DE toolkit)

> Un proyecto “local-first” para convertir **requerimientos** de Data Engineering en **acciones ejecutables**:  
> extraer datos, generar vistas, ingerir ficheros y estandarizar workflows… todo gobernado por **metadata**.

---

## Por qué existe CCP

En el día a día de un Data Engineer, muchos tickets son variaciones de lo mismo:

- *“Saca estas columnas de estas tablas y déjamelas en un CSV”*  
- *“Crea una view con este join para que negocio la consuma”*  
- *“Tengo un CSV: cárgalo en el target que diga la metadata”*  
- *“Esto es el requerimiento: hazlo repetible, parametrizable, auditable”*

**CCP** nace para materializar ese patrón:  
**una capa de control** (requirements + metadata) que alimenta un **runner** en Python capaz de ejecutar pipelines sin reescribir lógica cada vez.

La idea es simple:  
**no codear pipelines; codear un motor que ejecute pipelines declarados**.

---

## Qué hace CCP (hoy)

CCP lee dos tablas:

### 1) `DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS` (requerimientos)
Una “tabla de toma” donde describimos la tarea y, cuando aplica, especificamos:

- `datasource`: `file` o `MySQL`
- `task_type`:
  - `Extraction Data` → export a CSV
  - `View Creation` → crear/reemplazar view
- `tablename` (JSON array) → tablas fuente
- `tablecolumns` (JSON) → columnas a extraer por tabla
- `join_type` (JSON) → estructura de joins (left/right/inner + condiciones)

La clave: **el requerimiento contiene la intención y el contrato de salida**, no la implementación.

### 2) `DEV_CCP.T_METADATA` (gobierno/target)
Aquí se define, por `INGESTION_NAME`:

- qué está activo (`ACTIVE=1`)
- a qué `TARGET` se debe cargar o crear la vista  
  (en este repo se usa formato JSON: `{"database":"...","table":"..."}`)

---

## Flujos implementados

### A) datasource = `MySQL` + task_type = `Extraction Data`
1. Construye un `SELECT` dinámico a partir de los JSON del requirement  
2. Ejecuta el query contra MySQL
3. Exporta un CSV en `./extracciones/` con el formato:

