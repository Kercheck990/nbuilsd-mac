import express from 'express';

import { query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

export const tradesRouter = express.Router();
tradesRouter.use(requireAuth);

function bad(res, code, message, status = 400) {
  return res.status(status).json({ error: code, message });
}

/// Проверка: все inventory.id принадлежат userId и открыты.
async function assertOwnsOpen(client, ids, userId) {
  if (!ids.length) return false;
  const { rows } = await client.query(
    `SELECT id FROM inventory
      WHERE id = ANY($1::uuid[]) AND user_id = $2 AND status = 'open'`,
    [ids, userId]
  );
  return rows.length === ids.length;
}

function tradeJson(t) {
  return {
    id: t.id,
    status: t.status,
    created_at: t.created_at,
    from_nickname: t.from_nickname,
    from_avatar: t.from_avatar,
    from_badges: t.from_badges || [],
    to_nickname: t.to_nickname,
    to_avatar: t.to_avatar,
    to_badges: t.to_badges || [],
    offer: t.offer || [],
    ask: t.ask || [],
  };
}

async function hydrate(tradeRows) {
  const out = [];
  for (const t of tradeRows) {
    const ids = [...(t.offer_ids || []), ...(t.ask_ids || [])];
    let items = [];
    if (ids.length) {
      const { rows } = await query(
        `SELECT inv.id, inv.user_id, it.id AS item_id, it.name, it.price_coins,
                it.rarity, it.collection, it.image_asset, it.image_url
           FROM inventory inv
           JOIN items it ON it.id = inv.item_id
          WHERE inv.id = ANY($1::uuid[])`,
        [ids]
      );
      items = rows.map((r) => ({
        ...r,
        image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
      }));
    }
    const byId = Object.fromEntries(items.map((i) => [i.id, i]));
    out.push(
      tradeJson({
        ...t,
        offer: (t.offer_ids || []).map((id) => byId[id]).filter(Boolean),
        ask: (t.ask_ids || []).map((id) => byId[id]).filter(Boolean),
      })
    );
  }
  return out;
}

/// GET /api/trades/players?q= — поиск игроков для обмена.
tradesRouter.get('/players', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    const { rows } = await query(
      `SELECT u.nickname, u.avatar_url, u.badges,
              (SELECT COUNT(*) FROM inventory inv
                WHERE inv.user_id = u.id AND inv.status = 'open')::int AS items_count
         FROM users u
        WHERE u.id <> $1 AND u.email_verified AND NOT u.is_banned
          AND ($2 = '' OR u.nickname ILIKE '%' || $2 || '%')
        ORDER BY items_count DESC, u.nickname ASC
        LIMIT 20`,
      [req.user.id, q]
    );
    res.json({ players: rows });
  } catch (err) {
    next(err);
  }
});

/// GET /api/trades/showcase/:nickname — открытый инвентарь игрока (витрина).
tradesRouter.get('/showcase/:nickname', async (req, res, next) => {
  try {
    const { rows: users } = await query(
      `SELECT id FROM users WHERE lower(nickname) = lower($1) AND NOT is_banned`,
      [req.params.nickname]
    );
    if (!users.length) return bad(res, 'user_not_found', 'Игрок не найден', 404);
    const { rows } = await query(
      `SELECT inv.id, it.id AS item_id, it.name, it.price_coins, it.rarity,
              it.collection, it.image_asset, it.image_url
         FROM inventory inv
         JOIN items it ON it.id = inv.item_id
        WHERE inv.user_id = $1 AND inv.status = 'open'
        ORDER BY it.price_coins DESC`,
      [users[0].id]
    );
    res.json({
      items: rows.map((r) => ({
        ...r,
        image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
      })),
    });
  } catch (err) {
    next(err);
  }
});

/// POST /api/trades — создать предложение обмена.
tradesRouter.post('/', async (req, res, next) => {
  try {
    const toNickname = String(req.body.to_nickname || '').trim();
    const offerIds = Array.isArray(req.body.offer_ids)
      ? [...new Set(req.body.offer_ids.map(String))]
      : [];
    const askIds = Array.isArray(req.body.ask_ids)
      ? [...new Set(req.body.ask_ids.map(String))]
      : [];

    if (!toNickname) return bad(res, 'no_player', 'Не выбран игрок');
    if (!offerIds.length || !askIds.length) {
      return bad(res, 'empty_offer', 'Выберите предметы с обеих сторон');
    }
    if (offerIds.length > 10 || askIds.length > 10) {
      return bad(res, 'too_many', 'Максимум 10 предметов с каждой стороны');
    }

    const result = await withTransaction(async (client) => {
      const { rows: users } = await client.query(
        `SELECT id FROM users
          WHERE lower(nickname) = lower($1) AND email_verified AND NOT is_banned
          FOR UPDATE`,
        [toNickname]
      );
      if (!users.length) return { error: 'user_not_found' };
      const toId = users[0].id;
      if (toId === req.user.id) return { error: 'self_trade' };

      if (!(await assertOwnsOpen(client, offerIds, req.user.id))) {
        return { error: 'invalid_offer' };
      }
      if (!(await assertOwnsOpen(client, askIds, toId))) {
        return { error: 'invalid_ask' };
      }

      const { rows } = await client.query(
        `INSERT INTO trades (from_user, to_user, offer_ids, ask_ids)
         VALUES ($1, $2, $3::uuid[], $4::uuid[])
         RETURNING id`,
        [req.user.id, toId, offerIds, askIds]
      );
      return { id: rows[0].id };
    });

    if (result.error === 'user_not_found') return bad(res, 'user_not_found', 'Игрок не найден', 404);
    if (result.error === 'self_trade') return bad(res, 'self_trade', 'Нельзя меняться с собой');
    if (result.error === 'invalid_offer') {
      return bad(res, 'invalid_offer', 'Часть ваших предметов уже недоступна');
    }
    if (result.error === 'invalid_ask') {
      return bad(res, 'invalid_ask', 'Часть предметов игрока уже недоступна');
    }
    res.status(201).json({ ok: true, trade_id: result.id });
  } catch (err) {
    next(err);
  }
});

/// GET /api/trades — входящие и исходящие предложения.
tradesRouter.get('/', async (req, res, next) => {
  try {
    const base = `
      SELECT t.*, fu.nickname AS from_nickname, fu.avatar_url AS from_avatar,
             fu.badges AS from_badges, tu.nickname AS to_nickname,
             tu.avatar_url AS to_avatar, tu.badges AS to_badges
        FROM trades t
        JOIN users fu ON fu.id = t.from_user
        JOIN users tu ON tu.id = t.to_user`;
    const { rows: incoming } = await query(
      `${base} WHERE t.to_user = $1 ORDER BY t.created_at DESC LIMIT 50`,
      [req.user.id]
    );
    const { rows: outgoing } = await query(
      `${base} WHERE t.from_user = $1 ORDER BY t.created_at DESC LIMIT 50`,
      [req.user.id]
    );
    res.json({
      incoming: await hydrate(incoming),
      outgoing: await hydrate(outgoing),
    });
  } catch (err) {
    next(err);
  }
});

/// POST /api/trades/:id/accept — принять (атомарный обмен).
tradesRouter.post('/:id/accept', async (req, res, next) => {
  try {
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT * FROM trades WHERE id = $1 FOR UPDATE`,
        [req.params.id]
      );
      if (!rows.length) return { error: 'not_found' };
      const trade = rows[0];
      if (trade.to_user !== req.user.id) return { error: 'forbidden' };
      if (trade.status !== 'pending') return { error: 'already_decided' };

      // Предметы могли продать/проиграть/обменять после создания оффера —
      // перепроверяем владение и статус под блокировкой.
      if (!(await assertOwnsOpen(client, trade.offer_ids, trade.from_user))) {
        await client.query(
          `UPDATE trades SET status = 'cancelled', decided_at = now() WHERE id = $1`,
          [trade.id]
        );
        return { error: 'stale_offer' };
      }
      if (!(await assertOwnsOpen(client, trade.ask_ids, trade.to_user))) {
        await client.query(
          `UPDATE trades SET status = 'cancelled', decided_at = now() WHERE id = $1`,
          [trade.id]
        );
        return { error: 'stale_ask' };
      }

      await client.query(
        `UPDATE inventory SET user_id = $1 WHERE id = ANY($2::uuid[])`,
        [trade.to_user, trade.offer_ids]
      );
      await client.query(
        `UPDATE inventory SET user_id = $1 WHERE id = ANY($2::uuid[])`,
        [trade.from_user, trade.ask_ids]
      );
      await client.query(
        `UPDATE trades SET status = 'accepted', decided_at = now() WHERE id = $1`,
        [trade.id]
      );
      return { ok: true };
    });

    if (result.error === 'not_found') return bad(res, 'not_found', 'Сделка не найдена', 404);
    if (result.error === 'forbidden') return bad(res, 'forbidden', 'Не ваша сделка', 403);
    if (result.error === 'already_decided') {
      return bad(res, 'already_decided', 'Сделка уже завершена');
    }
    if (result.error === 'stale_offer' || result.error === 'stale_ask') {
      return bad(res, 'stale', 'Предметы уже недоступны, сделка отменена');
    }
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

/// POST /api/trades/:id/decline — отклонить (получатель).
tradesRouter.post('/:id/decline', async (req, res, next) => {
  try {
    const { rowCount } = await query(
      `UPDATE trades SET status = 'declined', decided_at = now()
        WHERE id = $1 AND to_user = $2 AND status = 'pending'`,
      [req.params.id, req.user.id]
    );
    if (!rowCount) return bad(res, 'not_found', 'Сделка не найдена', 404);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

/// POST /api/trades/:id/cancel — отозвать (создатель).
tradesRouter.post('/:id/cancel', async (req, res, next) => {
  try {
    const { rowCount } = await query(
      `UPDATE trades SET status = 'cancelled', decided_at = now()
        WHERE id = $1 AND from_user = $2 AND status = 'pending'`,
      [req.params.id, req.user.id]
    );
    if (!rowCount) return bad(res, 'not_found', 'Сделка не найдена', 404);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});
