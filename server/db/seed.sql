-- Стартовый каталог подарков.
-- image_asset должен совпадать с именем файла в assets/gifts/ у клиента.
INSERT INTO items (id, name, price_coins, rarity, collection, image_asset) VALUES
  ('nft_001', 'Desk Calendar',      120,  'common',    'Everyday Gifts', 'nft_001.png'),
  ('nft_002', 'Lucky Horseshoe',    240,  'common',    'Everyday Gifts', 'nft_002.png'),
  ('nft_003', 'Crystal Snow Globe', 480,  'rare',      'Winter Set',     'nft_003.png'),
  ('nft_004', 'Golden Star',        750,  'rare',      'Celestial',      'nft_004.png'),
  ('nft_005', 'Emerald Ring',       1200, 'epic',      'Jewelry',        'nft_005.png'),
  ('nft_006', 'Phoenix Feather',    1850, 'epic',      'Mythic Set',     'nft_006.png'),
  ('nft_007', 'Diamond Rose',       2600, 'epic',      'Jewelry',        'nft_007.png'),
  ('nft_008', 'Cosmic Egg',         3400, 'legendary', 'Celestial',      'nft_008.png'),
  ('nft_009', 'Crown of Ages',      5200, 'legendary', 'Royal Set',      'nft_009.png'),
  ('nft_010', 'Dragon Egg',         7800, 'legendary', 'Mythic Set',     'nft_010.png'),
  ('nft_011', 'Paper Plane',        90,   'common',    'Everyday Gifts', 'nft_011.png'),
  ('nft_012', 'Silver Bell',        310,  'rare',      'Winter Set',     'nft_012.png'),
  ('nft_013', 'Sapphire Heart',     1450, 'epic',      'Jewelry',        'nft_013.png'),
  ('nft_014', 'Meteor Shard',       2100, 'epic',      'Celestial',      'nft_014.png'),
  ('nft_015', 'Eternal Flame',      6100, 'legendary', 'Mythic Set',     'nft_015.png')
ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      price_coins = EXCLUDED.price_coins,
      rarity = EXCLUDED.rarity,
      collection = EXCLUDED.collection,
      image_asset = EXCLUDED.image_asset;

-- Гифты из assets/gifts/ (файл = id + .png).
INSERT INTO items (id, name, price_coins, rarity, collection, image_asset) VALUES
  ('present',  'Present',  100,  'common',    'Everyday Gifts', 'present.png'),
  ('cup',      'Cup',      180,  'common',    'Everyday Gifts', 'cup.png'),
  ('cake',     'Cake',     260,  'common',    'Everyday Gifts', 'cake.png'),
  ('flowers',  'Flowers',  340,  'common',    'Everyday Gifts', 'flowers.png'),
  ('heart',    'Heart',    500,  'rare',      'Winter Set',     'heart.png'),
  ('rose',     'Rose',     700,  'rare',      'Winter Set',     'rose.png'),
  ('ring',     'Ring',     950,  'rare',      'Jewelry',        'ring.png'),
  ('rocket',   'Rocket',   1500, 'epic',      'Celestial',      'rocket.png'),
  ('bull_run', 'Bull Run', 2200, 'epic',      'Celestial',      'bull_run.png'),
  ('diamond',  'Diamond',  3500, 'legendary', 'Jewelry',        'diamond.png'),
  ('bear',     'Bear',     4800, 'legendary', 'Mythic Set',     'bear.png')
ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      price_coins = EXCLUDED.price_coins,
      rarity = EXCLUDED.rarity,
      collection = EXCLUDED.collection,
      image_asset = EXCLUDED.image_asset;
