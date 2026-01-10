-- =========================================================
-- 1) DATABASE
-- =========================================================
CREATE DATABASE IF NOT EXISTS DEV_CCP
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE DEV_CCP;

-- =========================================================
-- 2) UNIDADES DE MEDIDA (UOM)
-- =========================================================
CREATE TABLE IF NOT EXISTS uom (
  uom_id        SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(16) NOT NULL UNIQUE,        -- KG, L, KWH, EA, CYCLE...
  name          VARCHAR(64) NOT NULL,               -- kilogramo, litro...
  dimension     ENUM('MASS','VOLUME','ENERGY','COUNT','TIME','OTHER') NOT NULL
) ENGINE=InnoDB;

INSERT INTO uom (code, name, dimension) VALUES
('KG',    'kilogramo', 'MASS'),
('L',     'litro',     'VOLUME'),
('KWH',   'kilovatio-hora', 'ENERGY'),
('EA',    'unidad',    'COUNT'),
('CYCLE', 'ciclo',     'COUNT')
ON DUPLICATE KEY UPDATE name = VALUES(name), dimension = VALUES(dimension);


INSERT INTO uom (code, name, dimension) VALUES
('G',  'gramo',  'MASS'),
('ML', 'mililitro', 'VOLUME')
ON DUPLICATE KEY UPDATE name = VALUES(name), dimension = VALUES(dimension);
-- =========================================================
-- 3) MATERIALES
-- =========================================================
CREATE TABLE IF NOT EXISTS material (
  material_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  material_code   VARCHAR(32) NOT NULL UNIQUE,   -- identificador "humano" opcional (MAT-0001...)
  name            VARCHAR(255) NOT NULL,
  category        ENUM('DIRECT','AUXILIARY','ENERGY','PACKAGING','CONSUMABLE') NOT NULL,
  default_uom_id  SMALLINT UNSIGNED NOT NULL,
  notes           VARCHAR(500) NULL,
  CONSTRAINT fk_material_uom
    FOREIGN KEY (default_uom_id) REFERENCES uom(uom_id)
) ENGINE=InnoDB;

CREATE INDEX idx_material_category ON material(category);

-- =========================================================
-- 4) PRODUCTOS
-- =========================================================
CREATE TABLE IF NOT EXISTS product (
  product_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku             VARCHAR(64) NOT NULL UNIQUE,
  name            VARCHAR(255) NOT NULL,
  default_uom_id  SMALLINT UNSIGNED NOT NULL,    -- normalmente EA
  notes           VARCHAR(500) NULL,
  CONSTRAINT fk_product_uom
    FOREIGN KEY (default_uom_id) REFERENCES uom(uom_id)
) ENGINE=InnoDB;

-- =========================================================
-- 5) BOM (Bill of Materials) = materiales por unidad de producto
-- =========================================================
CREATE TABLE IF NOT EXISTS bom_header (
  bom_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id     BIGINT UNSIGNED NOT NULL,
  version        VARCHAR(32) NOT NULL,
  effective_from DATE NOT NULL DEFAULT (CURRENT_DATE),
  effective_to   DATE NULL,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_bom_product_version (product_id, version),
  CONSTRAINT fk_bom_product
    FOREIGN KEY (product_id) REFERENCES product(product_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bom_line (
  bom_line_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bom_id          BIGINT UNSIGNED NOT NULL,
  material_id     BIGINT UNSIGNED NOT NULL,
  qty_per_unit    DECIMAL(18,6) NOT NULL,        -- cantidad por 1 unidad de producto
  uom_id          SMALLINT UNSIGNED NOT NULL,
  is_optional     BOOLEAN NOT NULL DEFAULT FALSE,
  notes           VARCHAR(500) NULL,
  CONSTRAINT fk_bomline_bom
    FOREIGN KEY (bom_id) REFERENCES bom_header(bom_id),
  CONSTRAINT fk_bomline_material
    FOREIGN KEY (material_id) REFERENCES material(material_id),
  CONSTRAINT fk_bomline_uom
    FOREIGN KEY (uom_id) REFERENCES uom(uom_id)
) ENGINE=InnoDB;

CREATE INDEX idx_bom_line_bom ON bom_line(bom_id);
CREATE INDEX idx_bom_line_material ON bom_line(material_id);

-- =========================================================
-- 6) MÁQUINAS + “AMORTIZACIÓN” EN CICLOS (sin euros)
-- =========================================================
CREATE TABLE IF NOT EXISTS machine (
  machine_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  machine_code       VARCHAR(64) NOT NULL UNIQUE,
  name               VARCHAR(255) NOT NULL,
  machine_type       VARCHAR(128) NOT NULL,      -- corte, costura, plancha, etc.
  cycle_uom_id       SMALLINT UNSIGNED NOT NULL DEFAULT 5, -- CYCLE
  units_per_cycle    DECIMAL(18,6) NOT NULL DEFAULT 1.000000, -- cuántas camisetas “equivale” 1 ciclo
  rated_total_cycles BIGINT UNSIGNED NOT NULL,   -- ciclos de vida estimados (capacidad total)
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  notes              VARCHAR(500) NULL,
  CONSTRAINT fk_machine_cycle_uom
    FOREIGN KEY (cycle_uom_id) REFERENCES uom(uom_id)
) ENGINE=InnoDB;

-- Contadores acumulados (lo que tú quieres para "amortización")
CREATE TABLE IF NOT EXISTS machine_counter (
  machine_id       BIGINT UNSIGNED PRIMARY KEY,
  cycles_used      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  units_produced   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  last_updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_machine_counter_machine
    FOREIGN KEY (machine_id) REFERENCES machine(machine_id)
) ENGINE=InnoDB;

-- Log detallado para sumar ciclos (auditable)
CREATE TABLE IF NOT EXISTS machine_cycle_log (
  log_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  machine_id     BIGINT UNSIGNED NOT NULL,
  event_ts       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cycles_delta   BIGINT UNSIGNED NOT NULL,  -- cuántos ciclos se suman
  units_delta    BIGINT UNSIGNED NOT NULL,  -- cuántas unidades se atribuyen
  reason         ENUM('PRODUCTION','TEST','SCRAP','MAINTENANCE','ADJUSTMENT') NOT NULL,
  ref_text       VARCHAR(255) NULL,         -- lote, orden, comentario...
  CONSTRAINT fk_cyclelog_machine
    FOREIGN KEY (machine_id) REFERENCES machine(machine_id)
) ENGINE=InnoDB;

CREATE INDEX idx_cyclelog_machine_ts ON machine_cycle_log(machine_id, event_ts);

-- =========================================================
-- 7) MANTENIMIENTO BASADO EN CICLOS (sin euros)
-- =========================================================
CREATE TABLE IF NOT EXISTS maintenance_plan (
  plan_id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  machine_id        BIGINT UNSIGNED NOT NULL,
  task_name         VARCHAR(255) NOT NULL,
  interval_cycles   BIGINT UNSIGNED NULL,   -- ej: cada 50.000 ciclos
  interval_days     INT UNSIGNED NULL,      -- opcional: o cada X días
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_mplan_machine
    FOREIGN KEY (machine_id) REFERENCES machine(machine_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maintenance_log (
  maintenance_id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  plan_id          BIGINT UNSIGNED NOT NULL,
  machine_id       BIGINT UNSIGNED NOT NULL,
  done_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cycles_at_time   BIGINT UNSIGNED NOT NULL,     -- ciclos acumulados cuando se realiza
  notes            VARCHAR(500) NULL,
  CONSTRAINT fk_mlog_plan
    FOREIGN KEY (plan_id) REFERENCES maintenance_plan(plan_id),
  CONSTRAINT fk_mlog_machine
    FOREIGN KEY (machine_id) REFERENCES machine(machine_id)
) ENGINE=InnoDB;


-- ===========================================================
-- 11) Creación de la vista final
-- ===========================================================
CREATE VIEW F_MAT_NEC
AS
SELECT
  p.product_id,
  p.sku,
  p.name            AS product_name,

  bh.bom_id,
  bh.version        AS bom_version,
  bh.effective_from,
  bh.effective_to,

  m.material_id,
  m.material_code,
  m.name            AS material_name,
  m.category        AS material_category,

  bl.qty_per_unit,
  u.code            AS uom_code,
  u.name            AS uom_name,

  bl.is_optional,
  COALESCE(bl.notes, m.notes) AS notes
FROM bom_header bh
JOIN product p      ON p.product_id = bh.product_id
JOIN bom_line bl    ON bl.bom_id = bh.bom_id
JOIN material m     ON m.material_id = bl.material_id
JOIN uom u          ON u.uom_id = bl.uom_id
WHERE bh.is_active = 1
  AND bh.effective_from <= CURDATE()
  AND (bh.effective_to IS NULL OR bh.effective_to >= CURDATE());

-- ===========================================================
-- Nuevo step: Crear la tabla de tiempos de trabajo.
-- ===========================================================
CREATE TABLE IF NOT EXISTS tiempo_trabajo (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku               VARCHAR(64) NOT NULL,
  rama              VARCHAR(128) NOT NULL,              -- ej: COCCION, ENVASADO, COSTURA...
  horas_por_unidad  DECIMAL(18,6) NOT NULL,             -- horas para producir 1 unidad de ese SKU en esa rama
  is_activo         BOOLEAN NOT NULL DEFAULT TRUE,
  vigente_desde     DATE NOT NULL DEFAULT (CURRENT_DATE),
  vigente_hasta     DATE NULL,
  notes             VARCHAR(500) NULL,
  INDEX idx_tt_sku (sku),
  INDEX idx_tt_active (is_activo),
  CONSTRAINT fk_tt_product_sku
    FOREIGN KEY (sku) REFERENCES product(sku)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS io_coef (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  output_sku    VARCHAR(64) NOT NULL,    -- columna j (lo que produces)
  input_sku     VARCHAR(64) NOT NULL,    -- fila i (lo que consumes)
  qty_per_unit  DECIMAL(18,6) NOT NULL,  -- unidades de input_sku por 1 unidad de output_sku
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  notes         VARCHAR(500) NULL,
  UNIQUE KEY uq_io (output_sku, input_sku),
  INDEX idx_io_active (is_active),
  CONSTRAINT fk_io_out FOREIGN KEY (output_sku) REFERENCES product(sku),
  CONSTRAINT fk_io_in  FOREIGN KEY (input_sku)  REFERENCES product(sku)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS pipeline_config (
  pipeline_id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pipeline_name            VARCHAR(64) NOT NULL,          -- ej: 'pl_leontief'
  horas_por_trabajador     DECIMAL(10,2) NOT NULL DEFAULT 160.00,
  strict_missing_labor     BOOLEAN NOT NULL DEFAULT TRUE,
  run_every_minutes        INT UNSIGNED NOT NULL DEFAULT 60,
  is_active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Items de demanda (una fila por SKU)
CREATE TABLE IF NOT EXISTS pipeline_demand_item (
  item_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pipeline_id   BIGINT UNSIGNED NOT NULL,
  sku           VARCHAR(64) NOT NULL,
  cantidad      DECIMAL(18,6) NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_pdi_pipeline FOREIGN KEY (pipeline_id) REFERENCES pipeline_config(pipeline_id),
  CONSTRAINT fk_pdi_product  FOREIGN KEY (sku) REFERENCES product(sku),
  UNIQUE KEY uq_pipeline_sku (pipeline_id, sku)
) ENGINE=InnoDB;

-- Último resultado (histórico)
CREATE TABLE IF NOT EXISTS pipeline_run (
  run_id                    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pipeline_id               BIGINT UNSIGNED NOT NULL,
  run_ts                    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  horas_por_trabajador      DECIMAL(10,2) NOT NULL,
  strict_missing_labor      BOOLEAN NOT NULL,
  demand_json               JSON NOT NULL,
  result_json               JSON NOT NULL,    -- dataframe a json (records)
  total_hours               DECIMAL(18,6) NOT NULL,
  total_workers_equivalent  DECIMAL(18,6) NOT NULL,
  CONSTRAINT fk_pr_pipeline FOREIGN KEY (pipeline_id) REFERENCES pipeline_config(pipeline_id),
  INDEX idx_pr_pipeline_ts (pipeline_id, run_ts)
) ENGINE=InnoDB;