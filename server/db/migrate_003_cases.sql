-- ===================================================================
-- NFT-Grader — миграция 003: NC валюта и кейсы
-- Идемпотентна: можно применять повторно (npm run migrate).
-- ===================================================================

-- --- NC валюта --------------------------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS balance_nc BIGINT NOT NULL DEFAULT 30 CHECK (balance_nc >= 0);
-- существующим игрокам у кого 0 (старые аккаунты) — выдать стартовые 30
UPDATE users SET balance_nc = 30 WHERE balance_nc = 0;

-- расширяем ledger для аудита NC (0 если операция только с coins)
ALTER TABLE ledger ADD COLUMN IF NOT EXISTS delta_nc BIGINT NOT NULL DEFAULT 0;
ALTER TABLE ledger ADD COLUMN IF NOT EXISTS balance_after_nc BIGINT NOT NULL DEFAULT 0;

-- --- Кейсы ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cases (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  price_nc      BIGINT NOT NULL DEFAULT 0 CHECK (price_nc >= 0),
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INT NOT NULL DEFAULT 0,
  image_asset   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS case_items (
  id            BIGSERIAL PRIMARY KEY,
  case_id       TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  item_id       TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  drop_chance   NUMERIC(6,2) NOT NULL CHECK (drop_chance > 0 AND drop_chance <= 100),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(case_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_case_items_case ON case_items(case_id);

CREATE TABLE IF NOT EXISTS case_openings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  case_id       TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  item_id       TEXT NOT NULL REFERENCES items(id),
  inventory_id  UUID REFERENCES inventory(id) ON DELETE SET NULL,
  price_paid    BIGINT NOT NULL DEFAULT 0,
  roll          NUMERIC(6,3) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_case_openings_user ON case_openings(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_case_openings_case ON case_openings(case_id, created_at DESC);

-- --- Сиды кейсов (6 штук: 5 из ТЗ + Milioner) — сохраняет ручные правки цены/содержимого из админки
INSERT INTO cases (id, name, price_nc, sort_order, image_asset) VALUES
  ('case_trash',   'Мусор',      0,  1, 'case_trash.png'),
  ('case_daily',   'Ежедневный', 0,  2, 'case_daily.png'),
  ('case_mclaren', 'McLaren',   10,  3, 'case_mclaren.png'),
  ('case_office',  'Офис',      15,  4, 'case_office.png'),
  ('case_burzh',   'Бурж',      20,  5, 'case_burzh.png'),
  ('case_milioner','Milioner',  80,  6, 'milioner.png')
ON CONFLICT (id) DO NOTHING;
