-- naming del proyecto p --> proyecto, xx --> cliente, z --> proyecto (pxxz)
-- p001 --> Arquitectura:  20 h-persona (x2), 16h bases de datos, 4 horas datalake-devops, 10h pipeline, 24h informe PBI
INSERT INTO DEV_EMPRESA_X.DIM_PROYECTOS(id, project_name,trabajadores_disp,trabajadores_nec,horas_totales_necesarias,
trabajadores_fijos, horas_semanales_nec) VALUES('p001','Proyecto Schreiber - DataEng Fac',0,6,94, 2, 40);

INSERT INTO DEV_EMPRESA_X.F_PROYECTOS VALUES('p001','Proyecto Schereiber - DataEng Fac','2025-04-01',
'Proyecto para la empresa Schreiber para la creación de pipelines para la visualización de datos de sus fábricas relativas a
su capacidad de producción, sus tiempos de producción y su stock','Data & Development','Schreiber','Pipeline y Dataviz');
--
INSERT INTO DEV_EMPRESA_X.DIM_PROYECTOS(id, project_name,trabajadores_disp,trabajadores_nec,horas_totales_necesarias,
trabajadores_fijos, horas_semanales_nec) VALUES('p011','Proyecto Familia Martínez - DataEng Fac',0,5,74, 2, 40);

INSERT INTO DEV_EMPRESA_X.DIM_PROYECTOS(id, project_name,trabajadores_disp,trabajadores_nec,horas_totales_necesarias,
trabajadores_fijos, horas_semanales_nec) VALUES('p012','Proyecto Familia Martínez - DataArch Fac',0,2,60, 0, 0);

INSERT INTO DEV_EMPRESA_X.F_PROYECTOS VALUES('p011','Proyecto Familia Martínez - DataEng Fac','2025-06-01',
'Proyecto para la empresa Familia Martínez para la creación de pipelines para la visualización de datos de sus fábricas relativas a
su capacidad de producción, sus tiempos de producción y sus ventas por cliente','Data & Development','Familia Martínez','Pipeline y Dataviz');


INSERT INTO DEV_EMPRESA_X.F_PROYECTOS VALUES('p012','Proyecto Familia Martínez - DataArch Fac','2025-07-01',
'Proyecto para la empresa Familia Martínez para la creación de su arquitectura en Databricks','Data & Development','Familia Martínez','Arquitectura');


INSERT INTO DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS
(
  task_id, task_title, task_description, project_id, task_type, have_reference,
  requested_by, created_at, business_goal, validation_by, priority, datasource,
  file_name, file_columns_name, tablename, tablecolumns, task_active, join_type, keys_join
)
VALUES
(
  'WON-001',
  'Data Extraction for Factories recognition',
  'Obtain a list of factories available to Know it and compare between them',
  'p001',
  'Extraction data',
  true,
  'Ron Dunford',
  '2026-01-12',
  'Factories Recognition',
  'Diana Dunford',
  'P1',
  'MySQL',
  NULL,
  NULL,
  CAST('["DEV_DPF.M_COMANS","DEV_DPF.M_COMANS_ACT"]' AS JSON),
  CAST('[
    {"table":"M_COMANS","columns":["fact_cod","fact_name","fact_country"]},
    {"table":"M_COMANS_ACT","columns":["number_lines","active","active_time"]}
  ]' AS JSON),
  true,
  CAST('[
    {"left":"M_COMANS","right":"M_COMANS_ACT","type":"LEFT","on":[["fact_cod","fact_cod"]]}
  ]' AS JSON),
  NULL
);

-- Nuevo codigo:

INSERT INTO DEV_EMPRESA_X.DIM_TASK_REQUIREMENTS
(
  task_id, task_title, task_description, project_id, task_type, have_reference,
  requested_by, created_at, business_goal, validation_by, priority, datasource,
  file_name, file_columns_name, tablename, tablecolumns, task_active, join_type, keys_join
)
VALUES
(
  'WON-002',
  'Creation of DIM_FACTORIES',
  'Obtain a list of factories available to Know it and compare between them',
  'p001',
  'View Creation',
  true,
  'Ron Dunford',
  '2026-01-14',
  'Factories Recognition',
  'Diana Dunford',
  'P1',
  'MySQL',
  NULL,
  NULL,
  CAST('["DEV_DPF.M_COMANS","DEV_DPF.M_COMANS_ACT"]' AS JSON),
  CAST('[
    {"table":"M_COMANS","columns":["fact_cod","fact_name","fact_country"]},
    {"table":"M_COMANS_ACT","columns":["number_lines","active","active_time"]}
  ]' AS JSON),
  true,
  CAST('[
    {"left":"M_COMANS","right":"M_COMANS_ACT","type":"LEFT","on":[["fact_cod","fact_cod"]]}
  ]' AS JSON),
  NULL
);

INSERT INTO DEV_DPF.M_COMANS
(fact_cod, fact_name, fact_country, fact_city, fact_type, partner_name)
VALUES
('F001','Fábrica Málaga Centro','ES','Málaga','PROPIA',NULL),
('F002','Comanufactura Norte','ES','Bilbao','COMANUFACTURA','Partner Norte S.L.'),
('F003','Externa Lisboa','PT','Lisboa','EXTERNA','Extern Co. Ltd.');

INSERT INTO DEV_DPF.M_COMANS_ACT
(fact_cod, active, active_time, number_lines, status_reason, source_system)
VALUES
('F001',1,'2026-01-12 08:00:00',12,'Operando','MES'),
('F002',0,'2026-01-12 08:00:00',NULL,'Parada mantenimiento','MES'),
('F003',1,'2026-01-12 08:00:00',5,'Operando','MES');


-- Fin nuevo codigo..