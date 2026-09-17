-- ===================================================================
-- NFT-Grader — схема PostgreSQL
-- Применить: psql "$DATABASE_URL" -f db/schema.sql
-- (или npm run migrate, что делает то же самое из Node)
-- ===================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------------
-- Пользователи
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT UNIQUE NOT NULL,
  password_hash   TEXT NOT NULL,
  nickname        TEXT UNIQUE NOT NULL,
  avatar_url      TEXT,
  locale          TEXT NOT NULL DEFAULT 'ru',
  balance_coins   BIGINT NOT NULL DEFAULT 0 CHECK (balance_coins >= 0),
  email_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  is_banned       BOOLEAN NOT NULL DEFAULT FALSE,
  -- клиентский сид для provably-fair; игрок может его менять
  client_seed     TEXT NOT NULL DEFAULT encode(gen_random_bytes(8), 'hex'),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_balance ON users (balance_coins DESC);

-- -------------------------------------------------------------------
-- Коды подтверждения почты
-- Хранится только хэш кода — утечка таблицы не даёт войти в аккаунт.
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_codes (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash   TEXT NOT NULL,
  purpose     TEXT NOT NULL DEFAULT 'verify',   -- verify | reset
  attempts    INT NOT NULL DEFAULT 0,
  expires_at  TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_codes_user ON email_codes (user_id, purpose, created_at DESC);

-- -------------------------------------------------------------------
-- Каталог подарков
-- image_asset — имя файла в assets/gifts/ у клиента,
-- image_url   — картинка из сети (если храните в CDN/S3)
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS items (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  price_coins  BIGINT NOT NULL CHECK (price_coins > 0),
  rarity       TEXT NOT NULL DEFAULT 'common',
  collection   TEXT NOT NULL DEFAULT '',
  image_asset  TEXT,
  image_url    TEXT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_items_price ON items (price_coins);

-- -------------------------------------------------------------------
-- Инвентарь: у одного предмета каталога может быть много экземпляров
-- у разных игроков, поэтому отдельная таблица владения.
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_id     TEXT NOT NULL REFERENCES items(id),
  -- open | staked | consumed | sold | withdrawn
  status      TEXT NOT NULL DEFAULT 'open',
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_user ON inventory (user_id, status);

-- -------------------------------------------------------------------
-- Раунды апгрейда (provably fair + аудит)
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rounds (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_item_id   TEXT NOT NULL REFERENCES items(id),
  stake_value      BIGINT NOT NULL,
  stake_coins      BIGINT NOT NULL DEFAULT 0,
  chance_percent   NUMERIC(6,3) NOT NULL,
  roll_percent     NUMERIC(6,3) NOT NULL,
  success          BOOLEAN NOT NULL,
  -- profit = (цена цели при победе) - ставка; отрицательный при проигрыше
  profit_coins     BIGINT NOT NULL,
  server_seed      TEXT NOT NULL,
  server_seed_hash TEXT NOT NULL,
  client_seed      TEXT NOT NULL,
  nonce            BIGINT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rounds_user_time ON rounds (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rounds_time ON rounds (created_at DESC);

-- -------------------------------------------------------------------
-- Платежи
-- Монеты начисляются ровно один раз: UNIQUE по (provider, external_id)
-- плюс флаг credited делают обработку вебхука идемпотентной.
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL,                 -- card(stripe) | crypto | stars
  external_id   TEXT,                          -- id счёта у провайдера
  amount_coins  BIGINT NOT NULL CHECK (amount_coins > 0),
  amount_money  NUMERIC(12,2) NOT NULL,
  currency      TEXT NOT NULL DEFAULT 'USD',
  status        TEXT NOT NULL DEFAULT 'pending', -- pending | paid | failed | expired
  credited      BOOLEAN NOT NULL DEFAULT FALSE,
  pay_url       TEXT,
  raw_payload   JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at       TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_external
  ON payments (provider, external_id) WHERE external_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments (user_id, created_at DESC);

-- -------------------------------------------------------------------
-- Движения баланса — полный аудит каждой монеты
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ledger (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta_coins BIGINT NOT NULL,
  reason      TEXT NOT NULL,   -- topup | upgrade_stake | upgrade_win | sell | admin
  ref_id      TEXT,
  balance_after BIGINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ledger_user ON ledger (user_id, created_at DESC);
