-- ===================================================================
-- NFT-Grader — миграция 002: трейды, тикеты, промокоды, админка,
-- 2FA/Telegram, рассылки, награды топ-3, ивенты, статусы, время в игре.
-- Идемпотентна: можно применять повторно (npm run migrate).
-- ===================================================================

-- --- Пользователи: новые колонки ------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS badges TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_id TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_username TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS tfa_enabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS playtime_seconds BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- --- Трейды ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS trades (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- inventory.id предметов создателя (уйдут партнёру)
  offer_ids   UUID[] NOT NULL DEFAULT '{}',
  -- inventory.id предметов партнёра (придут создателю)
  ask_ids     UUID[] NOT NULL DEFAULT '{}',
  status      TEXT NOT NULL DEFAULT 'pending',  -- pending|accepted|declined|cancelled
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at  TIMESTAMPTZ,
  CONSTRAINT no_self_trade CHECK (from_user <> to_user),
  CONSTRAINT non_empty_trade CHECK (array_length(offer_ids, 1) > 0 AND array_length(ask_ids, 1) > 0)
);

CREATE INDEX IF NOT EXISTS idx_trades_users ON trades (from_user, to_user, status, created_at DESC);

-- --- Тикеты поддержки -------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject     TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open',  -- open|answered|closed
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tickets_user ON tickets (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets (status, updated_at DESC);

CREATE TABLE IF NOT EXISTS ticket_messages (
  id          BIGSERIAL PRIMARY KEY,
  ticket_id   UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  author_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  is_admin    BOOLEAN NOT NULL DEFAULT FALSE,
  text        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_messages ON ticket_messages (ticket_id, created_at);

-- --- Промокоды ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS promocodes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT UNIQUE NOT NULL,
  coins       BIGINT NOT NULL CHECK (coins > 0),
  max_uses    INT,                       -- NULL = безлимит по людям (но 1 на человека)
  used_count  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  expires_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS promocode_redemptions (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_id     UUID NOT NULL REFERENCES promocodes(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, code_id)
);

-- --- Рассылки от админа -------------------------------------------------
CREATE TABLE IF NOT EXISTS broadcasts (
  id              BIGSERIAL PRIMARY KEY,
  admin_id        UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_nickname  TEXT NOT NULL DEFAULT 'Admin',
  text            TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- Награды топ-3 (выдаются 1 раз за категорию) ------------------------
CREATE TABLE IF NOT EXISTS top_rewards (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,             -- balance|inventory|hours|wins|profit
  amount      BIGINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

-- --- Настройки приложения (ивенты, музыка, саппорт) ---------------------
CREATE TABLE IF NOT EXISTS app_settings (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- event_x2/event_x4/event_saves: 'auto' (выходные, только x2+saves),
-- 'on' (всегда), 'off' (выключено). Дефолт — 'auto'.
INSERT INTO app_settings (key, value) VALUES
  ('event_x2', 'auto'),
  ('event_x4', 'off'),
  ('event_saves', 'auto'),
  ('music_url', ''),
  ('music_on', 'off'),
  ('support_tg', 'https://t.me/nftgrader_support'),
  ('tg_bot', '')
ON CONFLICT (key) DO NOTHING;

-- --- Telegram-коды привязки ----------------------------------------------
CREATE TABLE IF NOT EXISTS tg_codes (
  code        TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- Владелец: Kercheck — админ с полными правами -------------------------
UPDATE users
   SET is_admin = TRUE,
       badges = (SELECT array_agg(DISTINCT b)
                   FROM unnest(badges || ARRAY['owner','developer','verified']) AS b)
 WHERE lower(nickname) = 'kercheck';
