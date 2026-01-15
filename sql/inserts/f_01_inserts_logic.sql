INSERT INTO dim_act_rls_rule VALUES(1,'01-FTR-RULES-DATE-COLUMNS',1,1,"SN",'06','IST_CRE_TST','2026-01-12',null);
INSERT INTO dim_act_rls_rule VALUES(2,'01-FTR-RULES-DATE-COLUMNS',1,1,"Dairy",'06','IST_CRE_TST','2026-01-12',null);
INSERT INTO dim_act_rls_rule VALUES(3,'01-FTR-RULES-DATE-COLUMNS',1,1,"Waters",'06','IST_CRE_TST','2026-01-12',null);
-- Primero hacer unos updates
INSERT INTO dim_act_rls_rule VALUES(4,'01-FTR-RULES-DATE-COLUMNS',1,1,"Dairy",'99','dairy_tst','2026-01-13',null);
INSERT INTO dim_act_rls_rule VALUES(5,'01-FTR-RULES-DATE-COLUMNS',1,1,"Waters",'06','IST_CRE_TST','2026-01-12',null);

INSERT INTO t1 (cod, macro_category, cre_dat, payload) VALUES
('A001', 'SN',     DATE '2026-01-10', 'sn row 1'),
('A002', 'SN',     DATE '2025-12-20', 'sn row 2'),
('B001', 'Dairy',  DATE '2026-01-05', 'dairy row 1'),
('B002', 'Dairy',  DATE '2025-11-15', 'dairy row 2'),
('C001', 'Waters', DATE '2026-01-12', 'waters row 1'),
('C002', 'Waters', DATE '2025-10-10', 'waters row 2');

-- t2: valores de fechas (algunas nulas para ver cómo se comporta)
INSERT INTO t2 (cod, ist_type_cod, ist_cre_tst, ist_upd_tst, dairy_tst, water_tst) VALUES
('A001', '06',
  TIMESTAMP '2026-01-01 08:00:00',
  TIMESTAMP '2026-01-09 09:00:00',
  NULL,
  NULL
),
('A002', '05',
  TIMESTAMP '2025-12-01 10:00:00',
  TIMESTAMP '2025-12-19 11:00:00',
  NULL,
  NULL
),
('B001', NULL,
  NULL,
  NULL,
  TIMESTAMP '2026-01-03 12:30:00',
  NULL
),
('B002', '99',
  NULL,
  TIMESTAMP '2025-11-10 15:15:00',
  TIMESTAMP '2025-11-12 16:00:00',
  NULL
),
('C001', NULL,
  NULL,
  TIMESTAMP '2026-01-11 17:00:00',
  NULL,
  TIMESTAMP '2026-01-07 07:07:07'
),
('C002', NULL,
  NULL,
  TIMESTAMP '2025-10-09 18:00:00',
  NULL,
  TIMESTAMP '2025-10-01 06:06:06'
);
--- Fin del codigo reciente.
