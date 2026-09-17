import express from 'express';

import { applyBalance, query, withTransaction } from '../db.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';

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
              email_verified, is_banned, playtime_seconds, created_at
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
        RETURNING nickname, badges`,
      [nickname, badges]
    );
    if (!rows.length) return bad(res, 'user_not_found', 'Игрок не найден', 404);
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
    res.status(201).json({ ok: true, id: rows[0].id });
  } catch (err) {
    next(err);
  }
});
