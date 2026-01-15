CREATE DATABASE DEV_TESTING;
USE DEV_TESTING;
-- DROP TABLE dim_act_rls_rule;
CREATE TABLE dim_act_rls_rule (
  rule_id        BIGINT,
  rule_name      VARCHAR(90),
  active         BOOLEAN,
  priority       INT,              -- 1 = más específica / más alta
  macro_category VARCHAR(50),       -- SN, Dairy, Waters...
  ist_type_cod   VARCHAR(50),       -- puede ser NULL si no aplica
  ts_source      VARCHAR(50),       -- 'IST_CRE_TST', 'IST_UPD_TST', 'WAT_TST', etc.
  valid_from     DATE NULL,
  valid_to       DATE NULL
);

CREATE TABLE t1 (
  cod            VARCHAR(20) PRIMARY KEY,
  macro_category VARCHAR(50) NOT NULL,   -- SN, Dairy, Waters, etc..
  cre_dat        DATE NOT NULL,
  payload        VARCHAR(200)            -- columna dummy para simular más campos.
);

CREATE TABLE t2 (
  cod          VARCHAR(20) PRIMARY KEY,
  ist_type_cod VARCHAR(10),

  -- Fechas candidatas
  ist_cre_tst  TIMESTAMP,
  ist_upd_tst  TIMESTAMP,
  dairy_tst    TIMESTAMP,
  water_tst    TIMESTAMP
);

