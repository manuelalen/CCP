-- ===============================================================
--                  CREACIÓN DE LOS ORÍGENES
-- ===============================================================

CREATE DATABASE DEV_EMPRESA_X;

CREATE TABLE DEV_EMPRESA_X.DIM_PROYECTOS(
	id varchar(99) not null,
    project_name varchar(99),
    trabajadores_disp int, -- trabajadores disponibles en el proyecto
    trabajadores_nec int, -- trabajadores necesarios para el proyecto
    horas_totales_necesarias float, -- horas-persona necesarias para el proyecto,
    trabajadores_fijos int, -- trabajadores que deben de ser fijos por necesidades del proyecto
    horas_semanales_nec float, -- horas semanales fijas necesarias
    primary key(id)
);


CREATE TABLE DEV_EMPRESA_X.F_PROYECTOS(
	id varchar(99),
    project_name varchar(99),
    fecha_inicio varchar(99),
    descripcion longtext,
    departamento varchar(99),
    cliente varchar(99),
    mercancia varchar(99),
    primary key(id)
);

CREATE TABLE DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS (
	task_id varchar(90),
    task_title longtext,
    task_description longtext,
    project_id varchar(99), -- relacionarse con el id de la tabla M de projectos,
    task_type varchar(99), -- ej: Creación de vistas, Creación de pipelines,
    have_reference boolean, -- si tenemos una referencia de cómo debe quedar el source o el target
    requested_by varchar(50),
    created_at varchar(50),
    business_goal longtext,
    validation_by varchar(50),
    priority varchar(50),
    datasource varchar(90),
    file_name longtext,
    file_columns_name longtext,
    tablename JSON,
    tablecolumns JSON,
    task_active boolean,
    join_type JSON,
    keys_join longtext
);


CREATE TABLE IF NOT EXISTS DEV_DPF.M_COMANS (
  fact_cod        VARCHAR(50)  NOT NULL,              -- clave de fábrica (join key)
  fact_name       VARCHAR(255) NOT NULL,
  fact_country    VARCHAR(80)  NULL,
  fact_city       VARCHAR(120) NULL,

  -- Tipología: propias / comanufactura / externa, etc.
  fact_type       ENUM('PROPIA','COMANUFACTURA','EXTERNA','OTRA') NOT NULL DEFAULT 'OTRA',

  -- “Más” útil para DE (catálogo y explotación)
  legal_name      VARCHAR(255) NULL,                  -- razón social si difiere
  tax_id          VARCHAR(50)  NULL,                  -- NIF/VAT si aplica
  partner_name    VARCHAR(255) NULL,                  -- proveedor/partner si es externa/comanufactura
  country_iso2    CHAR(2)      NULL,
  address_line1   VARCHAR(255) NULL,
  postal_code     VARCHAR(20)  NULL,

  is_active_master TINYINT(1)  NOT NULL DEFAULT 1,    -- activo en el maestro (no confundir con actividad operativa)
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (fact_cod),
  KEY idx_fact_type (fact_type),
  KEY idx_fact_country_city (fact_country, fact_city)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS DEV_DPF.M_COMANS_ACT (
  act_id       BIGINT NOT NULL AUTO_INCREMENT,

  fact_cod     VARCHAR(50) NOT NULL,         -- FK a maestro
  active       TINYINT(1)  NOT NULL,         -- 1 activo, 0 inactivo
  active_time  DATETIME    NOT NULL,         -- desde cuándo / timestamp del estado

  number_lines INT NULL,                     -- métrica operativa (ej: líneas de producción activas)

  status_reason VARCHAR(255) NULL,           -- motivo del cambio/estado si lo tienes
  source_system VARCHAR(90)  NULL,           -- de dónde vino este estado (ERP/MES/etc.)
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (act_id),
  KEY idx_act_fact_time (fact_cod, active_time),
  KEY idx_act_active (active),

  CONSTRAINT fk_act_fact
    FOREIGN KEY (fact_cod) REFERENCES M_COMANS(fact_cod)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;
