-- Showcase: выбранные NFT для профиля (до 6)
CREATE TABLE IF NOT EXISTS user_showcase (
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  position     INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, inventory_id)
);
CREATE INDEX IF NOT EXISTS idx_showcase_user ON user_showcase(user_id, position);
