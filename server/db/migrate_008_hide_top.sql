-- Скрыть игрока из топа (админ выбирает кого скрыть, напр. себя)
ALTER TABLE users ADD COLUMN IF NOT EXISTS hide_from_top BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_users_hide_top ON users(hide_from_top) WHERE hide_from_top = TRUE;
