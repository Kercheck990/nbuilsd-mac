-- Звездочка на подарке — защита от продажи
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS is_starred BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_inventory_star ON inventory(user_id, is_starred) WHERE status='open';
