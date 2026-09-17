-- Сиды призов в кейсах — запускается ПОСЛЕ seed.sql (когда items уже есть)
DELETE FROM case_items WHERE case_id IN ('case_trash','case_daily','case_mclaren','case_office','case_burzh');

-- Мусор: очень жадный — 60% самый дешёвый (present 100), редкое почти не падает
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_trash','present', 60.00),
  ('case_trash','cup',     25.00),
  ('case_trash','cake',    10.00),
  ('case_trash','flowers',  3.00),
  ('case_trash','heart',    1.50),
  ('case_trash','rose',     0.50);

-- Ежедневный: чуть лучше, но всё равно жадный (EV ~280)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_daily','cup',     50.00),
  ('case_daily','cake',    25.00),
  ('case_daily','flowers', 12.00),
  ('case_daily','heart',    7.00),
  ('case_daily','rose',     4.00),
  ('case_daily','ring',     1.50),
  ('case_daily','rocket',   0.50);

-- McLaren 10 NC: жадный — топы падают <2% (EV ~990)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_mclaren','heart',     40.00),
  ('case_mclaren','rose',      25.00),
  ('case_mclaren','ring',      15.00),
  ('case_mclaren','rocket',    10.00),
  ('case_mclaren','bull_run',   5.00),
  ('case_mclaren','diamond',    3.00),
  ('case_mclaren','bear',       1.00),
  ('case_mclaren','nft_010',    0.50),
  ('case_mclaren','nft_015',    0.50);

-- Офис 15 NC: жадный (EV ~2090)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_office','ring',       35.00),
  ('case_office','rocket',     25.00),
  ('case_office','bull_run',   15.00),
  ('case_office','diamond',    10.00),
  ('case_office','bear',        7.00),
  ('case_office','nft_009',     3.00),
  ('case_office','nft_010',     2.00),
  ('case_office','nft_015',     2.00),
  ('case_office','nft_008',     1.00);

-- Бурж 20 NC: топ жадный — леге суммарно <10% (EV ~3060)
INSERT INTO case_items (case_id, item_id, drop_chance) VALUES
  ('case_burzh','rocket',      30.00),
  ('case_burzh','bull_run',    20.00),
  ('case_burzh','diamond',     15.00),
  ('case_burzh','bear',        12.00),
  ('case_burzh','nft_008',      8.00),
  ('case_burzh','nft_009',      5.00),
  ('case_burzh','nft_010',      4.00),
  ('case_burzh','nft_015',      3.00),
  ('case_burzh','nft_005',      2.00),
  ('case_burzh','nft_006',      1.00);
