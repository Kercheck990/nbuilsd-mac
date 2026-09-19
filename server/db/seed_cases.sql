-- Сиды призов в кейсах — запускается ПОСЛЕ seed.sql (когда items уже есть)
-- Сохраняет ручные правки из админки: не удаляет существующие case_items, только добавляет недостающие

-- Мусор: только 4 дешёвых подарка как просили
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_trash','present', 40.00),
  ('case_trash','cup',     30.00),
  ('case_trash','cake',    20.00),
  ('case_trash','flowers', 10.00)
ON CONFLICT (case_id, item_id) DO NOTHING;

-- Ежедневный: чуть лучше, но всё равно жадный (EV ~280)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_daily','cup',     50.00),
  ('case_daily','cake',    25.00),
  ('case_daily','flowers', 12.00),
  ('case_daily','heart',    7.00),
  ('case_daily','rose',     4.00),
  ('case_daily','ring',     1.50),
  ('case_daily','rocket',   0.50)
ON CONFLICT (case_id, item_id) DO NOTHING;

-- McLaren 10 NC: жадный — топы падают <2% (убраны nft_xxx, заменены на classic)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_mclaren','heart',                 40.00),
  ('case_mclaren','rose',                  25.00),
  ('case_mclaren','ring',                  15.00),
  ('case_mclaren','rocket',                10.00),
  ('case_mclaren','bull_run',               5.00),
  ('case_mclaren','diamond',                3.00),
  ('case_mclaren','bear',                   1.00),
  ('case_mclaren','classic_whip_cupcake',   0.50),
  ('case_mclaren','classic_xmax',           0.50)
ON CONFLICT (case_id, item_id) DO NOTHING;

-- Офис 15 NC: жадный (заменены nft)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_office','ring',                  35.00),
  ('case_office','rocket',                25.00),
  ('case_office','bull_run',              15.00),
  ('case_office','diamond',               10.00),
  ('case_office','bear',                   7.00),
  ('case_office','classic_snoop_doge',     3.00),
  ('case_office','classic_whip_cupcake',   2.00),
  ('case_office','classic_xmax',           2.00),
  ('case_office','classic_lunar_snake',    1.00)
ON CONFLICT (case_id, item_id) DO NOTHING;

-- Бурж 20 NC: топ жадный — леге суммарно <10% (заменены nft)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_burzh','rocket',                  30.00),
  ('case_burzh','bull_run',                20.00),
  ('case_burzh','diamond',                 15.00),
  ('case_burzh','bear',                    12.00),
  ('case_burzh','classic_lunar_snake',      8.00),
  ('case_burzh','classic_snoop_doge',       5.00),
  ('case_burzh','classic_whip_cupcake',     4.00),
  ('case_burzh','classic_xmax',             3.00),
  ('case_burzh','classic_swag_bag',         2.00),
  ('case_burzh','classic_snakebox',         1.00)
ON CONFLICT (case_id, item_id) DO NOTHING;

-- Milioner 80 NC: премиум кейс — высокие шансы на легендарки/эпики (цену настраиваете в cases.price_nc)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_milioner','diamond',                18.00),
  ('case_milioner','bear',                   15.00),
  ('case_milioner','classic_xmax',           12.00),
  ('case_milioner','classic_lunar_snake',    10.00),
  ('case_milioner','classic_snoop_doge',      8.00),
  ('case_milioner','classic_whip_cupcake',    7.00),
  ('case_milioner','classic_snakebox',        6.00),
  ('case_milioner','classic_swag_bag',        5.00),
  ('case_milioner','classic_timeless_book',   4.00),
  ('case_milioner','classic_stellar_rocket',  4.00),
  ('case_milioner','classic_victory_medal',   3.00),
  ('case_milioner','pepe',                    3.00),
  ('case_milioner','scare_cat',               2.50),
  ('case_milioner','precious_pearch',         2.50)
ON CONFLICT (case_id, item_id) DO NOTHING;
