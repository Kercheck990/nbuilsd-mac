-- Стартовый каталог подарков — 52 уникальных NFT (1 NFT = 1 картинка), дубликаты удалены.
-- image_asset должен совпадать с именем файла в assets/gifts/ у клиента.
-- ЦЕНЫ: price_coins — стоимость в монетах, настраивается вручную.
-- После правок: psql $DATABASE_URL -f db/seed.sql  или  npm run migrate

-- =========================================================
-- БАЗОВЫЕ ГИФТЫ (11) — цены как в последнем сиде
-- =========================================================
INSERT INTO items (id, name, price_coins, rarity, collection, image_asset) VALUES
  ('present',  'Present',   10,   'common',    'Everyday Gifts', 'present.png'),
  ('cup',      'Cup',       20,   'common',    'Everyday Gifts', 'cup.png'),
  ('cake',     'Cake',      30,   'common',    'Everyday Gifts', 'cake.png'),
  ('flowers',  'Flowers',   40,   'common',    'Everyday Gifts', 'flowers.png'),
  ('heart',    'Heart',     220,  'rare',      'Winter Set',     'heart.png'),
  ('rose',     'Rose',      350,  'rare',      'Winter Set',     'rose.png'),
  ('ring',     'Ring',      550,  'rare',      'Jewelry',        'ring.png'),
  ('rocket',   'Rocket',    950,  'epic',      'Celestial',      'rocket.png'),
  ('bull_run', 'Bull Run',  1500, 'epic',      'Celestial',      'bull_run.png'),
  ('diamond',  'Diamond',   3000, 'legendary', 'Jewelry',        'diamond.png'),
  ('bear',     'Bear',      4500, 'legendary', 'Mythic Set',     'bear.png')
ON CONFLICT (id) DO NOTHING;

-- =========================================================
-- CLASSIC GIFTS — 19 старых (цены как в последнем сиде)
-- =========================================================
INSERT INTO items (id, name, price_coins, rarity, collection, image_asset) VALUES
  ('classic_candy_cane',     'Candy Cane',     50,   'common',    'Classic Gifts', 'classic_candy_cane.png'),
  ('classic_clover_pin',     'Clover Pin',     90,   'common',    'Classic Gifts', 'classic_clover_pin.png'),
  ('classic_faith_amulet',   'Faith Amulet',   150,  'common',    'Classic Gifts', 'classic_faith_amulet.png'),
  ('classic_franch_socks',   'Franch Socks',   60,   'common',    'Classic Gifts', 'classic_franch_socks.png'),
  ('classic_happy_brownie',  'Happy Brownie',  130,  'common',    'Classic Gifts', 'classic_happy_brownie.png'),
  ('classic_icecream',       'Ice Cream',      180,  'common',    'Classic Gifts', 'classic_icecream.png'),
  ('classic_liberty_figure', 'Liberty Figure', 900,  'rare',      'Classic Gifts', 'classic_liberty_figure.png'),
  ('classic_loolpop',        'Loolpop',        100,  'common',    'Classic Gifts', 'classic_loolpop.png'),
  ('classic_lunar_snake',    'Lunar Snake',    3200, 'epic',      'Classic Gifts', 'classic_lunar_snake.png'),
  ('classic_mood_bag',       'Mood Bag',       400,  'rare',      'Classic Gifts', 'classic_mood_bag.png'),
  ('classic_mousse_cake',    'Mousse Cake',    480,  'rare',      'Classic Gifts', 'classic_mousse_cake.png'),
  ('classic_pool_float',     'Pool Float',     600,  'rare',      'Classic Gifts', 'classic_pool_float.png'),
  ('classic_ramen',          'Ramen',          750,  'rare',      'Classic Gifts', 'classic_ramen.png'),
  ('classic_snakebox',       'Snake Box',      1550, 'epic',      'Classic Gifts', 'classic_snakebox.png'),
  ('classic_snoop_doge',     'Snoop Doge',     2400, 'epic',      'Classic Gifts', 'classic_snoop_doge.png'),
  ('classic_swag_bag',       'Swag Bag',       1200, 'epic',      'Classic Gifts', 'classic_swag_bag.png'),
  ('classic_vicecream',      'Vice Cream',     260,  'rare',      'Classic Gifts', 'classic_vicecream.png'),
  ('classic_whip_cupcake',   'Whip Cupcake',   1900, 'epic',      'Classic Gifts', 'classic_whip_cupcake.png'),
  ('classic_xmax',           'Xmax',           6000, 'legendary', 'Classic Gifts', 'classic_xmax.png')
ON CONFLICT (id) DO NOTHING;

-- =========================================================
-- НОВЫЕ GIFTS — 22 шт, 1 к 1 картинка, цены настройте сами
-- =========================================================
INSERT INTO items (id, name, price_coins, rarity, collection, image_asset) VALUES
  ('classic_cooke_heart',    'Cooke Heart',    100, 'common', 'Classic Gifts', 'classic_cooke_heart.png'),
  ('classic_fine_pen',       'Fine Pen',       100, 'common', 'Classic Gifts', 'classic_fine_pen.png'),
  ('classic_ginger_cooke',   'Ginger Cooke',   100, 'common', 'Classic Gifts', 'classic_ginger_cooke.png'),
  ('classic_happy_b_day',    'Happy B-Day',    100, 'common', 'Classic Gifts', 'classic_happy_b_day.png'),
  ('classic_homemade_cake',  'Homemade Cake',  100, 'common', 'Classic Gifts', 'classic_homemade_cake.png'),
  ('classic_kissed_frog',    'Kissed Frog',    100, 'common', 'Classic Gifts', 'classic_kissed_frog.png'),
  ('classic_light_sword',    'Light Sword',    100, 'rare',   'Classic Gifts', 'classic_light_sword.png'),
  ('classic_party_spalker',  'Party Spalker',  100, 'common', 'Classic Gifts', 'classic_party_spalker.png'),
  ('classic_pet_snake',      'Pet Snake',      100, 'rare',   'Classic Gifts', 'classic_pet_snake.png'),
  ('classic_pretty_posy',    'Pretty Posy',    100, 'common', 'Classic Gifts', 'classic_pretty_posy.png'),
  ('classic_snoop_sigar',    'Snoop Sigar',    100, 'rare',   'Classic Gifts', 'classic_snoop_sigar.png'),
  ('classic_stellar_rocket', 'Stellar Rocket', 100, 'epic',   'Classic Gifts', 'classic_stellar_rocket.png'),
  ('classic_timeless_book',  'Timeless Book',  100, 'rare',   'Classic Gifts', 'classic_timeless_book.png'),
  ('classic_victory_medal',  'Victory Medal',  100, 'rare',   'Classic Gifts', 'classic_victory_medal.png'),
  ('classic_whitc_hat',      'Whitc Hat',      100, 'common', 'Classic Gifts', 'classic_whitc_hat.png'),
  ('durov_cap',              'Durov Cap',      100, 'rare',   'Classic Gifts', 'durov_cap.png'),
  ('input_key',              'Input Key',      100, 'common', 'Classic Gifts', 'input_key.png'),
  ('jacter_hat',             'Jacter Hat',     100, 'common', 'Classic Gifts', 'jacter_hat.png'),
  ('mini_oscar',             'Mini Oscar',     100, 'rare',   'Classic Gifts', 'mini_oscar.png'),
  ('pepe',                   'Pepe',           100, 'epic',   'Classic Gifts', 'pepe.png'),
  ('precious_pearch',        'Precious Pearch',100, 'rare',   'Classic Gifts', 'precious_pearch.png'),
  ('scare_cat',              'Scare Cat',      100, 'epic',   'Classic Gifts', 'scare_cat.png')
ON CONFLICT (id) DO NOTHING;

-- Удалить дубликаты: скрыть старые nft_001..015 (1 картинка = 1 NFT, дубликаты не показываем в каталоге, но оставляем для старых инвентарей)
UPDATE items SET is_active = FALSE WHERE id IN ('nft_001','nft_002','nft_003','nft_004','nft_005','nft_006','nft_007','nft_008','nft_009','nft_010','nft_011','nft_012','nft_013','nft_014','nft_015');
