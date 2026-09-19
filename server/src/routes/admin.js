import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

import { applyBalance, query, withTransaction } from '../db.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';
import { config } from '../config.js';

export const adminRouter = express.Router();
adminRouter.use(requireAuth, requireAdmin);

function bad(res, code, message, status = 400) {
  return res.status(status).json({ error: code, message });
}

/// Допустимые статусы-галочки.
export const BADGES = [
  'owner',
  'developer',
  'moderator',
  'media',
  'verified',
  'guarantor',
  'top',
];

/// GET /api/admin/users?search= — поиск игроков.
adminRouter.get('/users', async (req, res, next) => {
  try {
    const q = String(req.query.search || '').trim();
    const { rows } = await query(
      `SELECT id, nickname, email, avatar_url, balance_coins, is_admin, badges,
              email_verified, is_banned, hide_from_top, playtime_seconds, created_at
         FROM users
        WHERE ($1 = '' OR nickname ILIKE '%' || $1 || '%' OR email ILIKE '%' || $1 || '%')
        ORDER BY created_at DESC
        LIMIT 30`,
      [q]
    );
    res.json({ users: rows });
  } catch (err) {
    next(err);
  }
});

/// POST /api/admin/grant — выдать монеты и/или гифт.
adminRouter.post('/grant', async (req, res, next) => {
  try {
    const nickname = String(req.body.nickname || '').trim();
    const coins = Math.floor(Number(req.body.coins) || 0);
    const itemId = String(req.body.item_id || '').trim() || null;
    if (!nickname) return bad(res, 'no_user', 'Укажите никнейм');

    const result = await withTransaction(async (client) => {
      const { rows: users } = await client.query(
        `SELECT id FROM users WHERE lower(nickname) = lower($1) FOR UPDATE`,
        [nickname]
      );
      if (!users.length) return { error: 'user_not_found' };
      const userId = users[0].id;

      let balance = null;
      if (coins !== 0) {
        if (coins < 0) {
          const cur = await client.query(
            `SELECT balance_coins FROM users WHERE id = $1`,
            [userId]
          );
          if (cur.rows[0].balance_coins + coins < 0) return { error: 'too_much' };
        }
        balance = await applyBalance(client, userId, coins, 'admin', req.user.nickname);
      }

      let inventoryId = null;
      if (itemId) {
        const { rows: items } = await client.query(
          `SELECT id FROM items WHERE id = $1 AND is_active = TRUE`,
          [itemId]
        );
        if (!items.length) return { error: 'item_not_found' };
        const ins = await client.query(
          `INSERT INTO inventory (user_id, item_id, status) VALUES ($1, $2, 'open') RETURNING id`,
          [userId, itemId]
        );
        inventoryId = ins.rows[0].id;
      }
      // уведомления
      try {
        if (coins !== 0) await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'balance','Вам выдали на баланс','Администратор ${req.user.nickname} выдал вам ${coins} монет')`, [userId]);
        if (itemId) await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'balance','Вам выдали гифт','Администратор выдал вам гифт ${itemId}')`, [userId]);
      } catch (_) {}
      return { balance, inventory_id: inventoryId };
    });

    if (result.error === 'user_not_found') {
      return bad(res, 'user_not_found', 'Игрок не найден', 404);
    }
    if (result.error === 'item_not_found') {
      return bad(res, 'item_not_found', 'Гифт не найден', 404);
    }
    if (result.error === 'too_much') {
      return bad(res, 'too_much', 'Нельзя уйти в минус');
    }
    res.json({ ok: true, ...result });
  } catch (err) {
    next(err);
  }
});

/// POST /api/admin/badges — выдать/снять галочки и статусы.
adminRouter.post('/badges', async (req, res, next) => {
  try {
    const nickname = String(req.body.nickname || '').trim();
    const badges = Array.isArray(req.body.badges)
      ? [...new Set(req.body.badges.map(String))].filter((b) => BADGES.includes(b))
      : null;
    if (!nickname || !badges) return bad(res, 'bad_request', 'Никнейм и badges обязательны');

    // Галочку владельца может выдавать только владелец.
    const granterBadges = req.user.badges || [];
    if (badges.includes('owner') && !granterBadges.includes('owner')) {
      return bad(res, 'forbidden', 'Статус владельца выдаёт только владелец', 403);
    }

    const { rows } = await query(
      `UPDATE users SET badges = $2
        WHERE lower(nickname) = lower($1)
        RETURNING id, nickname, badges`,
      [nickname, badges]
    );
    if (!rows.length) return bad(res, 'user_not_found', 'Игрок не найден', 404);
    try {
      await query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'role','Вам выдали роль','Администратор ${req.user.nickname} обновил ваши роли: ${badges.join(', ')}')`, [rows[0].id]);
    } catch (_) {}
    res.json({ ok: true, user: rows[0] });
  } catch (err) {
    next(err);
  }
});

/// POST /api/admin/ban — блокировка/разблокировка.
adminRouter.post('/ban', async (req, res, next) => {
  try {
    const nickname = String(req.body.nickname || '').trim();
    const banned = req.body.banned !== false;
    const { rows } = await query(
      `UPDATE users SET is_banned = $2
        WHERE lower(nickname) = lower($1)
        RETURNING nickname, is_banned`,
      [nickname, banned]
    );
    if (!rows.length) return bad(res, 'user_not_found', 'Игрок не найден', 404);
    res.json({ ok: true, user: rows[0] });
  } catch (err) {
    next(err);
  }
});

/// POST /api/admin/hide_top — скрыть/показать игрока в топе
adminRouter.post('/hide_top', async (req, res, next) => {
  try {
    const nickname = String(req.body.nickname || '').trim();
    const hide = req.body.hide !== false;
    const { rows } = await query(
      `UPDATE users SET hide_from_top = $2 WHERE lower(nickname) = lower($1) RETURNING nickname, hide_from_top`,
      [nickname, hide]
    );
    if (!rows.length) return bad(res, 'user_not_found', 'Игрок не найден', 404);
    res.json({ ok: true, user: rows[0] });
  } catch (err) { next(err); }
});

/// POST /api/admin/wipe — обнулить всех игроков (инвентарь, раунды, баланс, часы) кроме админов
adminRouter.post('/wipe', async (req, res, next) => {
  try {
    const confirm = String(req.body.confirm || '').trim();
    if (confirm !== 'WIPE') return bad(res, 'confirm', 'Подтвердите WIPE');
    await query(`DELETE FROM inventory WHERE user_id IN (SELECT id FROM users WHERE NOT is_admin)`);
    await query(`DELETE FROM rounds WHERE user_id IN (SELECT id FROM users WHERE NOT is_admin)`);
    await query(`DELETE FROM case_openings WHERE user_id IN (SELECT id FROM users WHERE NOT is_admin)`);
    await query(`DELETE FROM trades WHERE from_user IN (SELECT id FROM users WHERE NOT is_admin) OR to_user IN (SELECT id FROM users WHERE NOT is_admin)`);
    await query(`DELETE FROM top_rewards WHERE user_id IN (SELECT id FROM users WHERE NOT is_admin)`);
    await query(`UPDATE users SET balance_coins = 0, balance_nc = 0, playtime_seconds = 0 WHERE NOT is_admin`);
    await query(`DELETE FROM user_showcase WHERE user_id IN (SELECT id FROM users WHERE NOT is_admin)`);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

const SETTING_KEYS = ['event_x2', 'event_x4', 'event_saves', 'music_url', 'music_on', 'support_tg', 'tg_bot'];
const SETTING_VALUES = {
  event_x2: ['auto', 'on', 'off'],
  event_x4: ['on', 'off'],
  event_saves: ['auto', 'on', 'off'],
  music_on: ['on', 'off'],
};

/// GET /api/admin/settings — все настройки.
adminRouter.get('/settings', async (req, res, next) => {
  try {
    const { rows } = await query(`SELECT key, value FROM app_settings`);
    res.json({ settings: Object.fromEntries(rows.map((r) => [r.key, r.value])) });
  } catch (err) {
    next(err);
  }
});

/// POST /api/admin/settings — поменять настройку (ивенты, музыка, саппорт).
adminRouter.post('/settings', async (req, res, next) => {
  try {
    const key = String(req.body.key || '');
    const value = String(req.body.value ?? '');
    if (!SETTING_KEYS.includes(key)) return bad(res, 'bad_key', 'Неизвестная настройка');
    if (SETTING_VALUES[key] && !SETTING_VALUES[key].includes(value)) {
      return bad(res, 'bad_value', `Допустимо: ${SETTING_VALUES[key].join(', ')}`);
    }
    await query(
      `INSERT INTO app_settings (key, value, updated_at) VALUES ($1, $2, now())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [key, value]
    );
    res.json({ ok: true, key, value });
  } catch (err) {
    next(err);
  }
});

const __adminDir = path.dirname(fileURLToPath(import.meta.url));
const musicDir = path.join(__adminDir, '../../public/music');
try { fs.mkdirSync(musicDir, { recursive: true }); } catch {}
const musicStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, musicDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.mp3';
    const base = path.basename(file.originalname, ext).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 30) || 'music';
    cb(null, `${base}_${Date.now()}${ext}`);
  }
});
const musicUpload = multer({
  storage: musicStorage,
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('audio/') || file.originalname.match(/\.(mp3|wav|ogg|m4a|aac)$/i)) cb(null, true);
    else cb(new Error('only audio files'));
  }
});

// POST /api/admin/music/upload — загрузить музыку на сервер, автоматом включает её игрокам
adminRouter.post('/music/upload', musicUpload.single('music'), async (req, res, next) => {
  try {
    if (!req.file) return bad(res, 'no_file', 'Файл не получен');
    const filename = req.file.filename;
    const urlPath = `/music/${filename}`;
    const fullUrl = `${config.publicUrl.replace(/\/$/, '')}${urlPath}`;
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('music_url', $1, now()) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`, [fullUrl]);
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('music_on', 'on', now()) ON CONFLICT (key) DO UPDATE SET value = 'on', updated_at = now()`);
    res.json({ ok: true, url: fullUrl, path: urlPath, file: filename });
  } catch (err) { next(err); }
});

// GET /api/admin/music/list — список файлов в public/music
adminRouter.get('/music/list', async (req, res, next) => {
  try {
    const files = fs.existsSync(musicDir) ? fs.readdirSync(musicDir).filter(f => f.match(/\.(mp3|wav|ogg|m4a|aac)$/i)) : [];
    res.json({ files });
  } catch (err) { next(err); }
});

// POST /api/admin/music/play — включить конкретный файл для всех
adminRouter.post('/music/play', async (req, res, next) => {
  try {
    const file = String(req.body.file || '').trim();
    if (!file) return bad(res, 'no_file', 'Укажите файл');
    const fullPath = path.join(musicDir, file);
    if (!fs.existsSync(fullPath)) return bad(res, 'not_found', 'Файл не найден');
    const urlPath = `/music/${file}`;
    const fullUrl = `${config.publicUrl.replace(/\/$/, '')}${urlPath}`;
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('music_url', $1, now()) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`, [fullUrl]);
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('music_on', 'on', now()) ON CONFLICT (key) DO UPDATE SET value = 'on', updated_at = now()`);
    res.json({ ok: true, url: fullUrl });
  } catch (err) { next(err); }
});

// POST /api/admin/music/stop — остановить музыку у всех
adminRouter.post('/music/stop', async (req, res, next) => {
  try {
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('music_on', 'off', now()) ON CONFLICT (key) DO UPDATE SET value = 'off', updated_at = now()`);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

/// POST /api/admin/events/:key/on — включить ивент на N минут (таймер в app_settings event_<key>_until)
adminRouter.post('/events/:key/on', async (req, res, next) => {
  try {
    const key = String(req.params.key || '').trim();
    if (!['x2','x4','saves'].includes(key)) return bad(res, 'bad_key', 'unknown event');
    const minutes = Math.max(1, Math.min(1440, parseInt(req.body.duration_minutes, 10) || 15));
    const until = new Date(Date.now() + minutes * 60000).toISOString();
    await query(`INSERT INTO app_settings (key, value, updated_at) VALUES ($1,$2,now()) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()`, [`event_${key}_until`, until]);
    res.json({ ok: true, key, until });
  } catch (err) { next(err); }
});
adminRouter.post('/events/:key/off', async (req, res, next) => {
  try {
    const key = String(req.params.key || '').trim();
    if (!['x2','x4','saves'].includes(key)) return bad(res, 'bad_key', 'unknown event');
    await query(`DELETE FROM app_settings WHERE key=$1`, [`event_${key}_until`]);
    res.json({ ok: true, key });
  } catch (err) { next(err); }
});

/// POST /api/admin/broadcast — написать всем игрокам от своего лица.
adminRouter.post('/broadcast', async (req, res, next) => {
  try {
    const text = String(req.body.text || '').trim().slice(0, 500);
    if (!text) return bad(res, 'no_text', 'Пустое сообщение');
    const { rows } = await query(
      `INSERT INTO broadcasts (admin_id, admin_nickname, text)
       VALUES ($1, $2, $3) RETURNING id, created_at`,
      [req.user.id, req.user.nickname, text]
    );
    // уведомление всем: вышло обновление
    try {
      await query(`INSERT INTO notifications (user_id, type, title, body) SELECT id,'update','Вышло обновление','Администратор ${req.user.nickname}: ${text}' FROM users WHERE NOT is_banned`);
    } catch (_) {}
    res.status(201).json({ ok: true, id: rows[0].id });
  } catch (err) {
    next(err);
  }
});

// ── Gifts CRUD ──
adminRouter.get('/items', async (req, res, next) => {
  try {
    const q = String(req.query.search || '').trim();
    const { rows } = await query(
      `SELECT id, name, price_coins, rarity, collection, image_asset, image_url, is_active, created_at
         FROM items
        WHERE ($1 = '' OR id ILIKE '%' || $1 || '%' OR name ILIKE '%' || $1 || '%')
        ORDER BY price_coins ASC
        LIMIT 100`,
      [q]
    );
    res.json({ items: rows });
  } catch (err) { next(err); }
});

adminRouter.post('/items', async (req, res, next) => {
  try {
    const id = String(req.body.id || '').trim();
    const name = String(req.body.name || '').trim();
    const price = Math.floor(Number(req.body.price_coins) || 0);
    const rarity = String(req.body.rarity || 'common').toLowerCase();
    const collection = String(req.body.collection || '').trim();
    const image_asset = String(req.body.image_asset || '').trim();
    const image_url = String(req.body.image_url || '').trim() || null;
    if (!id || !name || price <= 0) return bad(res, 'bad_input', 'id, name, price_coins обязательны');
    if (!['common','rare','epic','legendary'].includes(rarity)) return bad(res, 'bad_rarity', 'rarity: common/rare/epic/legendary');
    await query(
      `INSERT INTO items (id, name, price_coins, rarity, collection, image_asset, image_url, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE)
       ON CONFLICT (id) DO NOTHING`,
      [id, name, price, rarity, collection, image_asset || id + '.png', image_url]
    );
    const { rows } = await query(`SELECT * FROM items WHERE id=$1`, [id]);
    res.status(201).json({ ok: true, item: rows[0] });
  } catch (err) { next(err); }
});

adminRouter.put('/items/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const name = String(req.body.name || '').trim();
    const price = Math.floor(Number(req.body.price_coins) || 0);
    const rarity = String(req.body.rarity || '').toLowerCase();
    const collection = req.body.collection !== undefined ? String(req.body.collection).trim() : undefined;
    const image_asset = req.body.image_asset !== undefined ? String(req.body.image_asset).trim() : undefined;
    const image_url = req.body.image_url !== undefined ? String(req.body.image_url).trim() || null : undefined;
    const is_active = req.body.is_active !== undefined ? Boolean(req.body.is_active) : undefined;
    const sets = [];
    const vals = [];
    let idx = 1;
    if (name) { sets.push(`name=$${idx++}`); vals.push(name); }
    if (price) { sets.push(`price_coins=$${idx++}`); vals.push(price); }
    if (rarity && ['common','rare','epic','legendary'].includes(rarity)) { sets.push(`rarity=$${idx++}`); vals.push(rarity); }
    if (collection !== undefined) { sets.push(`collection=$${idx++}`); vals.push(collection); }
    if (image_asset !== undefined) { sets.push(`image_asset=$${idx++}`); vals.push(image_asset); }
    if (image_url !== undefined) { sets.push(`image_url=$${idx++}`); vals.push(image_url); }
    if (is_active !== undefined) { sets.push(`is_active=$${idx++}`); vals.push(is_active); }
    if (!sets.length) return bad(res, 'no_changes', 'Нет изменений');
    vals.push(id);
    const { rows } = await query(`UPDATE items SET ${sets.join(', ')} WHERE id=$${idx} RETURNING *`, vals);
    if (!rows.length) return bad(res, 'not_found', 'Гифт не найден', 404);
    res.json({ ok: true, item: rows[0] });
  } catch (err) { next(err); }
});

adminRouter.delete('/items/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    await query(`UPDATE items SET is_active=FALSE WHERE id=$1`, [id]);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

// ── Cases CRUD ──
adminRouter.get('/cases', async (req, res, next) => {
  try {
    const { rows } = await query(`SELECT id, name, price_nc, image_asset, sort_order, is_active FROM cases ORDER BY sort_order`);
    res.json({ cases: rows });
  } catch (err) { next(err); }
});

adminRouter.post('/cases', async (req, res, next) => {
  try {
    const id = String(req.body.id || '').trim();
    const name = String(req.body.name || '').trim();
    const price = Math.floor(Number(req.body.price_nc) || 0);
    const image_asset = String(req.body.image_asset || '').trim();
    const sort = parseInt(req.body.sort_order, 10) || 0;
    if (!id || !name) return bad(res, 'bad_input', 'id и name обязательны');
    await query(
      `INSERT INTO cases (id, name, price_nc, image_asset, sort_order, is_active) VALUES ($1,$2,$3,$4,$5,TRUE)
       ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, price_nc=EXCLUDED.price_nc, image_asset=EXCLUDED.image_asset, sort_order=EXCLUDED.sort_order, is_active=TRUE`,
      [id, name, price, image_asset, sort]
    );
    const { rows } = await query(`SELECT * FROM cases WHERE id=$1`, [id]);
    res.status(201).json({ ok: true, case: rows[0] });
  } catch (err) { next(err); }
});

adminRouter.put('/cases/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const name = req.body.name !== undefined ? String(req.body.name).trim() : undefined;
    const price = req.body.price_nc !== undefined ? Math.floor(Number(req.body.price_nc)) : undefined;
    const image_asset = req.body.image_asset !== undefined ? String(req.body.image_asset).trim() : undefined;
    const sort = req.body.sort_order !== undefined ? parseInt(req.body.sort_order, 10) : undefined;
    const is_active = req.body.is_active !== undefined ? Boolean(req.body.is_active) : undefined;
    const sets = []; const vals = []; let idx = 1;
    if (name !== undefined) { sets.push(`name=$${idx++}`); vals.push(name); }
    if (price !== undefined) { sets.push(`price_nc=$${idx++}`); vals.push(price); }
    if (image_asset !== undefined) { sets.push(`image_asset=$${idx++}`); vals.push(image_asset); }
    if (sort !== undefined) { sets.push(`sort_order=$${idx++}`); vals.push(sort); }
    if (is_active !== undefined) { sets.push(`is_active=$${idx++}`); vals.push(is_active); }
    if (!sets.length) return bad(res, 'no_changes', 'Нет изменений');
    vals.push(id);
    const { rows } = await query(`UPDATE cases SET ${sets.join(', ')} WHERE id=$${idx} RETURNING *`, vals);
    if (!rows.length) return bad(res, 'not_found', 'Кейс не найден', 404);
    res.json({ ok: true, case: rows[0] });
  } catch (err) { next(err); }
});

adminRouter.delete('/cases/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    await query(`UPDATE cases SET is_active=FALSE WHERE id=$1`, [id]);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

adminRouter.get('/cases/:id/items', async (req, res, next) => {
  try {
    const caseId = String(req.params.id);
    const { rows } = await query(
      `SELECT ci.item_id, ci.drop_chance, it.name, it.price_coins FROM case_items ci JOIN items it ON it.id=ci.item_id WHERE ci.case_id=$1 ORDER BY ci.drop_chance DESC`,
      [caseId]
    );
    res.json({ items: rows });
  } catch (err) { next(err); }
});

adminRouter.put('/cases/:id/items', async (req, res, next) => {
  try {
    const caseId = String(req.params.id);
    const items = Array.isArray(req.body.items) ? req.body.items : [];
    // items: [{item_id, drop_chance}]
    await withTransaction(async (client) => {
      await client.query(`DELETE FROM case_items WHERE case_id=$1`, [caseId]);
      for (const it of items) {
        const itemId = String(it.item_id || '').trim();
        const chance = Number(it.drop_chance) || 0;
        if (!itemId || chance <= 0) continue;
        await client.query(`INSERT INTO case_items (case_id, item_id, drop_chance) VALUES ($1,$2,$3)`, [caseId, itemId, chance]);
      }
    });
    res.json({ ok: true });
  } catch (err) { next(err); }
});
