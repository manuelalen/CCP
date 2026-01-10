-- =========================================================
-- 8) DATOS DEL EJEMPLO: CAMISETA BÁSICA + MATERIALES + BOM
-- =========================================================

-- Producto
INSERT INTO product (sku, name, default_uom_id, notes)
SELECT 'TSHIRT_BASIC_M', 'Camiseta básica algodón (talla M)', u.uom_id,
       'Ejemplo base: peso final ~180 g; BOM aproximada'
FROM uom u
WHERE u.code = 'EA'
ON DUPLICATE KEY UPDATE name = VALUES(name), notes = VALUES(notes);


-- SELECT * FROM product;
-- Materiales (los de tu tabla anterior)
-- Nota: material_code lo puedes mantener como MAT-0001, etc.
INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-FABRIC-COTTON', 'Tejido algodón (jersey)', 'DIRECT', u.uom_id, 'Incluye merma de corte'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), category=VALUES(category), default_uom_id=VALUES(default_uom_id), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-THREAD-PES', 'Hilo de coser (poliéster)', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-LABEL-COMP', 'Etiqueta composición/talla', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-LABEL-BRAND', 'Etiqueta marca', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-INK-SERIG', 'Tinta serigrafía', 'DIRECT', u.uom_id, 'Solo si impresa'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-BAG-UNIT', 'Bolsa individual (papel/plástico)', 'PACKAGING', u.uom_id
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-CARD-INSERT', 'Cartoncillo/insert', 'PACKAGING', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-BOX-CARDBOARD', 'Caja de cartón (prorrateada)', 'PACKAGING', u.uom_id, 'Prorrateo por unidad'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-WATER-PROCESS', 'Agua de proceso (tintura/lavado)', 'AUXILIARY', u.uom_id, 'Muy variable'
FROM uom u WHERE u.code='L'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-DYES', 'Colorantes', 'AUXILIARY', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-SALTS-ALKALI', 'Sales/álcalis (tintura)', 'AUXILIARY', u.uom_id, 'Ej: sal + carbonato'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id) 
SELECT 'MAT-DETERG-ENZ', 'Detergentes/enzimas (lavado)', 'AUXILIARY', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-ELEC', 'Electricidad (corte + costura)', 'ENERGY', u.uom_id, 'kWh'
FROM uom u WHERE u.code='KWH'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-STEAM-HEAT', 'Calor/vapor (planchado/acabado)', 'ENERGY', u.uom_id, 'kWh-equivalente'
FROM uom u WHERE u.code='KWH'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-PROTECT-FILM', 'Film/papel protector (prorrateado)', 'CONSUMABLE', u.uom_id, 'Separadores/protecciones'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id, notes) 
SELECT 'MAT-NEEDLES', 'Agujas/cuchillas (desgaste prorrateado)', 'CONSUMABLE', u.uom_id, 'Se puede modelar como EA o “uso”'
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

-- SELECT * FROM material;
-- DELETE FROM material;
-- BOM v1
INSERT INTO bom_header (product_id, version, effective_from, is_active)
SELECT p.product_id, 'v1', CURRENT_DATE, TRUE
FROM product p
WHERE p.sku='TSHIRT_BASIC_M'
ON DUPLICATE KEY UPDATE is_active=VALUES(is_active);

-- Líneas BOM (cantidades por 1 camiseta)
-- (Tejido 0,200 kg; hilo 0,004 kg; etiquetas 1+1 ud; tinta 0,010 kg; etc.)
INSERT INTO bom_line (bom_id, material_id, qty_per_unit, uom_id, is_optional, notes)
SELECT bh.bom_id, m.material_id, x.qty, u.uom_id, x.optional, x.notes
FROM bom_header bh
JOIN product p ON p.product_id = bh.product_id AND p.sku='TSHIRT_BASIC_M' AND bh.version='v1'
JOIN (
  SELECT 'MAT-FABRIC-COTTON'  AS material_code, 0.200000 AS qty, 'KG'  AS uom_code, 0 AS optional, 'Incluye merma de corte' AS notes UNION ALL
  SELECT 'MAT-THREAD-PES',        0.004000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-LABEL-COMP',        1.000000,      'EA',  0, NULL UNION ALL
  SELECT 'MAT-LABEL-BRAND',       1.000000,      'EA',  1, 'Si aplica' UNION ALL
  SELECT 'MAT-INK-SERIG',         0.010000,      'KG',  1, 'Solo si impresa' UNION ALL
  SELECT 'MAT-BAG-UNIT',          1.000000,      'EA',  0, NULL UNION ALL
  SELECT 'MAT-CARD-INSERT',       0.015000,      'KG',  1, 'Si aplica' UNION ALL
  SELECT 'MAT-BOX-CARDBOARD',     0.030000,      'KG',  0, 'Prorrateada' UNION ALL
  SELECT 'MAT-WATER-PROCESS',    20.000000,      'L',   1, 'Si hay tintura/lavado' UNION ALL
  SELECT 'MAT-DYES',              0.006000,      'KG',  1, 'Si teñida' UNION ALL
  SELECT 'MAT-SALTS-ALKALI',      0.050000,      'KG',  1, 'Si teñida' UNION ALL
  SELECT 'MAT-DETERG-ENZ',        0.003000,      'KG',  1, 'Si hay lavado/acabado' UNION ALL
  SELECT 'MAT-ELEC',              0.200000,      'KWH', 0, NULL UNION ALL
  SELECT 'MAT-STEAM-HEAT',        0.300000,      'KWH', 1, 'Si hay plancha/vapor' UNION ALL
  SELECT 'MAT-PROTECT-FILM',      0.002000,      'KG',  1, NULL UNION ALL
  SELECT 'MAT-NEEDLES',           0.001000,      'EA',  1, 'Modelado como prorrateo'
) x ON 1=1
JOIN material m ON m.material_code = x.material_code
JOIN uom u ON u.code = x.uom_code
WHERE NOT EXISTS (
  SELECT 1 FROM bom_line bl
  WHERE bl.bom_id = bh.bom_id AND bl.material_id = m.material_id
);

-- =========================================================
-- 9) EJEMPLO MÁQUINAS (ciclos + contadores)
-- =========================================================
INSERT INTO machine (machine_code, name, machine_type, units_per_cycle, rated_total_cycles, notes)
VALUES
('MC-CUT-01',   'Cortadora automática', 'CUTTING',  50.0,  200000, '1 ciclo = 1 extendido+corte; produce ~50 camisetas'),
('MC-SEW-01',   'Máquina de coser industrial', 'SEWING', 1.0, 1500000, '1 ciclo = 1 camiseta cosida (equivalente)'),
('MC-IRON-01',  'Plancha/Vaporizador industrial', 'FINISHING', 1.0, 800000, '1 ciclo = 1 camiseta planchada')
ON DUPLICATE KEY UPDATE name=VALUES(name), units_per_cycle=VALUES(units_per_cycle), rated_total_cycles=VALUES(rated_total_cycles), notes=VALUES(notes);

-- Inicializa contadores si no existen
INSERT INTO machine_counter (machine_id)
SELECT m.machine_id
FROM machine m
WHERE NOT EXISTS (
  SELECT 1 FROM machine_counter mc WHERE mc.machine_id = m.machine_id
);


-- =========================================================
-- 10) EJEMPLO: sumar ciclos (uso de máquina) SIN TRIGGERS
-- (1) Insertas un log
-- (2) Actualizas el contador acumulado
-- =========================================================
-- Ej: lote "Lote-0001": 100 camisetas cosidas en MC-SEW-01 => 100 ciclos y 100 unidades
INSERT INTO machine_cycle_log (machine_id, cycles_delta, units_delta, reason, ref_text)
SELECT m.machine_id, 100, 100, 'PRODUCTION', 'Lote-0001'
FROM machine m WHERE m.machine_code='MC-SEW-01';

UPDATE machine_counter mc
        JOIN
    machine m ON m.machine_id = mc.machine_id 
SET 
    mc.cycles_used = mc.cycles_used + 100,
    mc.units_produced = mc.units_produced + 100
WHERE
    m.machine_code = 'MC-SEW-01';

-- 1) Producto
INSERT INTO product (sku, name, default_uom_id, notes)
SELECT 'MEAL_RICE_CHICKEN_CURRY_400G',
       'Comida preparada: arroz con pollo al curry (bandeja ~400g)',
       u.uom_id,
       'BOM aproximada por ración'
FROM uom u
WHERE u.code = 'EA'
ON DUPLICATE KEY UPDATE name = VALUES(name), notes = VALUES(notes);

-- 2) Materiales (ingredientes + packaging + energía + limpieza)
-- Ingredientes (DIRECT)
INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-RICE-BASMATI', 'Arroz basmati (seco)', 'DIRECT', u.uom_id, NULL
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), category=VALUES(category), default_uom_id=VALUES(default_uom_id);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-CHICKEN', 'Pollo troceado', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-COCONUT-MILK', 'Leche de coco', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='L'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-ONION', 'Cebolla', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-GARLIC', 'Ajo', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-CURRY-PASTE', 'Pasta/mezcla de curry', 'DIRECT', u.uom_id, 'Puede ser pasta o mezcla de especias'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-OIL-VEG', 'Aceite vegetal', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='L'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-WATER-STOCK', 'Caldo/agua', 'DIRECT', u.uom_id, 'Para cocción/salsa'
FROM uom u WHERE u.code='L'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-SALT', 'Sal', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-SUGAR', 'Azúcar', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-CILANTRO', 'Cilantro', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-LIME-JUICE', 'Zumo de lima', 'DIRECT', u.uom_id
FROM uom u WHERE u.code='L'
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Packaging
INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-TRAY', 'Bandeja (PP/PET)', 'PACKAGING', u.uom_id
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-LIDDING-FILM', 'Film/tapa termosellado', 'PACKAGING', u.uom_id, 'Prorrateado'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id)
SELECT 'MAT-LABEL', 'Etiqueta', 'PACKAGING', u.uom_id
FROM uom u WHERE u.code='EA'
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Energía / Auxiliares
INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-ELEC-COOKPACK', 'Electricidad (cocción + envasado)', 'ENERGY', u.uom_id, 'kWh por ración (aprox.)'
FROM uom u WHERE u.code='KWH'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

INSERT INTO material (material_code, name, category, default_uom_id, notes)
SELECT 'MAT-CLEAN-CHEM', 'Detergente/desinfectante (limpieza)', 'AUXILIARY', u.uom_id, 'Prorrateado'
FROM uom u WHERE u.code='KG'
ON DUPLICATE KEY UPDATE name=VALUES(name), notes=VALUES(notes);

-- 3) BOM v1
INSERT INTO bom_header (product_id, version, effective_from, is_active)
SELECT p.product_id, 'v1', CURRENT_DATE, TRUE
FROM product p
WHERE p.sku='MEAL_RICE_CHICKEN_CURRY_400G'
ON DUPLICATE KEY UPDATE is_active=VALUES(is_active);

-- 4) Líneas BOM (por 1 ración)
INSERT INTO bom_line (bom_id, material_id, qty_per_unit, uom_id, is_optional, notes)
SELECT bh.bom_id, m.material_id, x.qty, u.uom_id, x.optional, x.notes
FROM bom_header bh
JOIN product p ON p.product_id = bh.product_id
JOIN (
  SELECT 'MAT-RICE-BASMATI'    AS material_code, 0.080000 AS qty, 'KG'  AS uom_code, 0 AS optional, NULL AS notes UNION ALL
  SELECT 'MAT-CHICKEN',           0.120000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-COCONUT-MILK',      0.080000,      'L',   0, NULL UNION ALL
  SELECT 'MAT-ONION',             0.030000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-GARLIC',            0.005000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-CURRY-PASTE',       0.010000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-OIL-VEG',           0.010000,      'L',   0, NULL UNION ALL
  SELECT 'MAT-WATER-STOCK',       0.150000,      'L',   0, NULL UNION ALL
  SELECT 'MAT-SALT',              0.002000,      'KG',  0, NULL UNION ALL
  SELECT 'MAT-SUGAR',             0.002000,      'KG',  1, 'Opcional' UNION ALL
  SELECT 'MAT-CILANTRO',          0.005000,      'KG',  1, 'Opcional' UNION ALL
  SELECT 'MAT-LIME-JUICE',        0.010000,      'L',   1, 'Opcional' UNION ALL
  SELECT 'MAT-TRAY',              1.000000,      'EA',  0, NULL UNION ALL
  SELECT 'MAT-LIDDING-FILM',      0.003000,      'KG',  0, 'Prorrateado' UNION ALL
  SELECT 'MAT-LABEL',             1.000000,      'EA',  0, NULL UNION ALL
  SELECT 'MAT-ELEC-COOKPACK',     0.250000,      'KWH', 0, NULL UNION ALL
  SELECT 'MAT-CLEAN-CHEM',        0.001000,      'KG',  0, 'Prorrateado'
) x ON 1=1
JOIN material m ON m.material_code = x.material_code
JOIN uom u ON u.code = x.uom_code
WHERE p.sku='MEAL_RICE_CHICKEN_CURRY_400G'
  AND bh.version='v1'
  AND NOT EXISTS (
    SELECT 1 FROM bom_line bl
    WHERE bl.bom_id = bh.bom_id AND bl.material_id = m.material_id
  );