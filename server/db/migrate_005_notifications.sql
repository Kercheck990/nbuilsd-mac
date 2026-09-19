-- Notifications, daily tasks, NPC, shop donations
CREATE TABLE IF NOT EXISTS notifications (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

-- Daily tasks
CREATE TABLE IF NOT EXISTS daily_tasks (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  reward_coins INT NOT NULL DEFAULT 0,
  reward_item_id TEXT REFERENCES items(id),
  requirement_type TEXT NOT NULL, -- upgrade|case_open|trade|login
  requirement_count INT NOT NULL DEFAULT 1,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS user_daily_progress (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_id     TEXT NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE,
  progress    INT NOT NULL DEFAULT 0,
  completed   BOOLEAN NOT NULL DEFAULT FALSE,
  claimed     BOOLEAN NOT NULL DEFAULT FALSE,
  date        DATE NOT NULL DEFAULT CURRENT_DATE,
  PRIMARY KEY (user_id, task_id, date)
);
-- Per-user boosts for shop (blessing/x2/x4) 15 min
ALTER TABLE users ADD COLUMN IF NOT EXISTS boost_saves_until TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS boost_x2_until TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS boost_x4_until TIMESTAMPTZ;

-- NPC balance is balance_nc already, but ensure starter 100 NPC for new users?
-- Themes stored in user pref, but also ensure app_settings for shop?
INSERT INTO daily_tasks (id, title, description, reward_coins, requirement_type, requirement_count, sort_order) VALUES
  ('daily_login','Ежедневный вход','Зайдите в игру',50,'login',1,1),
  ('daily_upgrade','Апгрейдер','Сделайте 3 апгрейда',150,'upgrade',3,2),
  ('daily_case','Кейсы','Откройте 2 кейса',100,'case_open',2,3)
ON CONFLICT (id) DO NOTHING;
