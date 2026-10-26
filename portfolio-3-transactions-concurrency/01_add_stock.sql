-- =====================================================
-- CarePoint: Migration 01 (Portfolio 3)
-- Adds pharmacy stock levels so concurrency on dispensing can be tested.
-- =====================================================
ALTER TABLE medications
  ADD COLUMN IF NOT EXISTS stock_quantity INT NOT NULL DEFAULT 0
  CONSTRAINT chk_stock_non_negative CHECK (stock_quantity >= 0);
 
UPDATE medications SET stock_quantity = 500;
 
-- Deliberately low stock on the antimalarial for the concurrency demo
UPDATE medications SET stock_quantity = 5
WHERE name = 'Artemether/Lumefantrine';
 
SELECT medication_id, name, form, strength, stock_quantity
FROM medications ORDER BY medication_id;
