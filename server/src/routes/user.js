import express from 'express';
import { config } from '../config.js';
import { applyBalance, query, withTransaction } from '../db.js';
import { publicUser, requireAuth } from '../middleware/auth.js';

export const userRouter = express.Router();
userRouter.use(requireAuth);

/// GET /api/me
userRouter.get('/me', (req, res) => {
  res.json({ user: publicUser(req.user) });
});

/// GET /api/inventory — открытые предметы игрока.
/// id здесь — идентификатор ЭКЗЕМПЛЯРА (inventory.id), именно его
/// клиент присылает в ставку и в продажу.
userRouter.get('/inventory', async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT inv.id,
              it.name, it.price_coins, it.rarity, it.collection,
              it.image_asset, it.image_url, it.id AS item_id,
              inv.acquired_at, COALESCE(inv.is_starred,false) as is_starred
         FROM inventory inv
         JOIN items it ON it.id = inv.item_id
        WHERE inv.user_id = $1 AND inv.status = 'open'
        ORDER BY inv.acquired_at DESC`,
      [req.user.id]
    );
    res.json({
      items: rows.map((r) => ({
        ...r,
        image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
        is_owned: true,
        is_starred: !!r.is_starred,
      })),
    });
  } catch (err) {
    next(err);
  }
});

/// POST /api/inventory/:id/star — поставить/снять звёздочку (защита от продажи)
userRouter.post('/inventory/:id/star', async (req, res, next) => {
  try {
    const starred = !!req.body.starred;
    const { rows } = await query(
      `UPDATE inventory SET is_starred=$3 WHERE id=$1 AND user_id=$2 AND status='open' RETURNING id, is_starred`,
      [req.params.id, req.user.id, starred]
    );
    if (!rows.length) return res.status(404).json({ error: 'item_not_found' });
    res.json({ id: rows[0].id, is_starred: !!rows[0].is_starred });
  } catch (err) { next(err); }
});

/// POST /api/inventory/sell-all — продать все незазвёздоченные
userRouter.post('/inventory/sell-all', async (req, res, next) => {
  try {
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT inv.id, it.price_coins FROM inventory inv
           JOIN items it ON it.id=inv.item_id
          WHERE inv.user_id=$1 AND inv.status='open' AND COALESCE(inv.is_starred,false)=false
          FOR UPDATE OF inv`,
        [req.user.id]
      );
      if (!rows.length) return { sold:0, gained:0, balance: req.user.balance_coins };
      let total=0;
      for (const r of rows) {
        const price=Math.floor(r.price_coins*config.game.sellRatio);
        await client.query(`UPDATE inventory SET status='sold' WHERE id=$1`,[r.id]);
        total+=price;
      }
      const balance=await applyBalance(client, req.user.id, total, 'sell_all', `sell_all:${rows.length}`);
      return { sold: rows.length, gained: total, balance };
    });
    res.json(result);
  } catch (err){ next(err); }
});

/// POST /api/inventory/:id/sell — продать предмет за монеты.
userRouter.post('/inventory/:id/sell', async (req, res, next) => {
  try {
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT inv.id, it.price_coins, COALESCE(inv.is_starred,false) as is_starred
           FROM inventory inv
           JOIN items it ON it.id = inv.item_id
          WHERE inv.id = $1 AND inv.user_id = $2 AND inv.status = 'open'
          FOR UPDATE OF inv`,
        [req.params.id, req.user.id]
      );
      if (!rows.length) return null;
      if (rows[0].is_starred) return { starred: true };

      const price = Math.floor(rows[0].price_coins * config.game.sellRatio);
      await client.query(`UPDATE inventory SET status = 'sold' WHERE id = $1`, [
        rows[0].id,
      ]);
      const balance = await applyBalance(
        client,
        req.user.id,
        price,
        'sell',
        rows[0].id
      );
      return { price, balance };
    });

    if (!result) {
      return res.status(404).json({ error: 'item_not_found', message: 'Предмет не найден' });
    }
    if (result.starred) {
      return res.status(400).json({ error: 'starred', message: 'Предмет помечен ⭐ — снимите звёздочку' });
    }
    res.json({ sold_for: result.price, balance_coins: result.balance });
  } catch (err) {
    next(err);
  }
});

/// GET /api/history — последние раунды игрока.
userRouter.get('/history', async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT r.id, r.chance_percent, r.roll_percent, r.success,
              r.stake_value, r.profit_coins, r.created_at,
              r.server_seed, r.server_seed_hash, r.client_seed, r.nonce,
              it.name AS target_name, it.price_coins AS target_price
         FROM rounds r
         JOIN items it ON it.id = r.target_item_id
        WHERE r.user_id = $1
        ORDER BY r.created_at DESC
        LIMIT 50`,
      [req.user.id]
    );
    res.json({ rounds: rows });
  } catch (err) {
    next(err);
  }
});

/// POST /api/heartbeat — клиент шлёт раз в минуту, пока открыт.
/// Копим наигранные часы для топа.
userRouter.post('/heartbeat', async (req, res, next) => {
  try {
    const { rows } = await query(
      `UPDATE users
          SET playtime_seconds = playtime_seconds +
                LEAST(180, GREATEST(0, EXTRACT(EPOCH FROM (now() - COALESCE(last_seen_at, now() - interval '60 seconds'))))::bigint),
              last_seen_at = now()
        WHERE id = $1
        RETURNING playtime_seconds`,
      [req.user.id]
    );
    res.json({ ok: true, playtime_seconds: Number(rows[0].playtime_seconds) });
  } catch (err) {
    next(err);
  }
});

/// GET /api/broadcasts — последние объявления от администрации.
userRouter.get('/broadcasts', async (req, res, next) => {
  try {
    const limit = Math.min(20, Math.max(1, parseInt(req.query.limit, 10) || 10));
    const { rows } = await query(
      `SELECT id, admin_nickname, text, created_at FROM broadcasts
        ORDER BY id DESC LIMIT $1`,
      [limit]
    );
    res.json({ broadcasts: rows });
  } catch (err) {
    next(err);
  }
});

/// GET /api/settings — публичные настройки (музыка, саппорт, бот).
userRouter.get('/settings', async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT key, value FROM app_settings
        WHERE key IN ('music_url', 'music_on', 'support_tg', 'tg_bot')`
    );
    res.json({ settings: Object.fromEntries(rows.map((r) => [r.key, r.value])) });
  } catch (err) {
    next(err);
  }
});

/// GET /api/events — активные ивенты (x2/x4/Сейвы) + окна выходных.
userRouter.get('/events', async (req, res, next) => {
  try {
    const { activeEvents } = await import('../services/events.js');
    res.json(await activeEvents());
  } catch (err) {
    next(err);
  }
});

/// PUT /api/me — смена ника/языка игроком.
userRouter.put('/me', async (req, res, next) => {
  try {
    const nickname = req.body.nickname != null ? String(req.body.nickname).trim() : null;
    const locale = ['ru', 'uk', 'en'].includes(req.body.locale) ? req.body.locale : null;
    if (nickname != null && (nickname.length < 3 || nickname.length > 20)) {
      return res.status(400).json({ error: 'invalid_nickname', message: 'Ник: 3–20 символов' });
    }
    if (nickname) {
      const taken = await query(
        `SELECT 1 FROM users WHERE lower(nickname) = lower($1) AND id <> $2`,
        [nickname, req.user.id]
      );
      if (taken.rows.length) {
        return res.status(409).json({ error: 'nickname_taken', message: 'Ник занят' });
      }
    }
     const { rows } = await query(
      `UPDATE users
          SET nickname = COALESCE($2, nickname),
              locale = COALESCE($3, locale)
        WHERE id = $1
        RETURNING id, email, nickname, avatar_url, locale, balance_coins, balance_nc,
                  email_verified, is_admin, badges, telegram_id, telegram_username,
                  tfa_enabled, playtime_seconds`,
      [req.user.id, nickname, locale]
    );
    const { publicUser } = await import('../middleware/auth.js');
    res.json({ user: publicUser(rows[0]) });
  } catch (err) {
    next(err);
  }
});

/// GET /api/users/search?q= — поиск игроков (для трейдов/профилей).
userRouter.get('/users/search', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    if (!q) return res.json({ users: [] });
    const { rows } = await query(
      `SELECT nickname, avatar_url, badges FROM users
        WHERE nickname ILIKE '%' || $1 || '%' AND NOT is_banned
        ORDER BY nickname ASC LIMIT 10`,
      [q]
    );
    res.json({ users: rows });
  } catch (err) {
    next(err);
  }
});

/// GET /api/users/:nickname — публичный профиль: статусы, статистика, витрина.
userRouter.get('/users/:nickname', async (req, res, next) => {
  try {
    const { rows: users } = await query(
      `SELECT id, nickname, avatar_url, badges, playtime_seconds, created_at,
              email_verified
         FROM users WHERE lower(nickname) = lower($1) AND NOT is_banned`,
      [req.params.nickname]
    );
    if (!users.length) {
      return res.status(404).json({ error: 'user_not_found', message: 'Игрок не найден' });
    }
    const u = users[0];
    const statsRes = await query(
      `SELECT COUNT(*)::int AS rounds,
              COUNT(*) FILTER (WHERE success)::int AS wins,
              COALESCE(MAX(profit_coins), 0)::bigint AS best_profit,
              COALESCE(SUM(stake_value), 0)::bigint AS total_staked
         FROM rounds WHERE user_id = $1`,
      [u.id]
    );
    const invRes = await query(
      `SELECT inv.id, it.id AS item_id, it.name, it.price_coins, it.rarity,
              it.collection, it.image_asset, it.image_url
         FROM inventory inv
         JOIN items it ON it.id = inv.item_id
        WHERE inv.user_id = $1 AND inv.status = 'open'
        ORDER BY it.price_coins DESC
        LIMIT 6`,
      [u.id]
    );
    res.json({
      profile: {
        nickname: u.nickname,
        avatar_url: u.avatar_url,
        badges: u.badges || [],
        hours: Math.floor(Number(u.playtime_seconds || 0) / 3600),
        created_at: u.created_at,
        stats: statsRes.rows[0],
        showcase: invRes.rows.map((r) => ({
          ...r,
          image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
        })),
      },
    });
  } catch (err) {
    next(err);
  }
});
