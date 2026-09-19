import express from 'express';
import crypto from 'node:crypto';
import { applyNcBalance, query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { activeEvents, luckMultiplier } from '../services/events.js';
import { incDailyProgress } from './daily.js';

export const casesRouter = express.Router();

// --- helpers ---------------------------------------------------------------
function pickByChance(items, roll) {
  // items: [{item_id, drop_chance}]
  // roll 0..100
  let acc = 0;
  for (const it of items) {
    acc += Number(it.drop_chance);
    if (roll < acc) return it;
  }
  return items[items.length - 1];
}

// GET /api/cases — список кейсов
casesRouter.get('/', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT id, name, price_nc, image_asset, sort_order, is_active
         FROM cases WHERE is_active = TRUE ORDER BY sort_order`
    );
    // для каждого кейса посчитаем кол-во предметов
    const ids = rows.map((r) => r.id);
    let counts = {};
    if (ids.length) {
      const c = await query(
        `SELECT case_id, COUNT(*)::int as cnt FROM case_items WHERE case_id = ANY($1) GROUP BY case_id`,
        [ids]
      );
      for (const r of c.rows) counts[r.case_id] = r.cnt;
    }
    res.json({
      cases: rows.map((r) => ({
        id: r.id,
        name: r.name,
        price_nc: Number(r.price_nc),
        image_asset: r.image_asset ? `assets/case/${r.image_asset}` : null,
        items_count: counts[r.id] || 0,
      })),
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/cases/:id — детали кейса + шансы
casesRouter.get('/:id', requireAuth, async (req, res, next) => {
  try {
    const caseId = String(req.params.id);
    const { rows: cr } = await query(`SELECT id, name, price_nc, image_asset FROM cases WHERE id=$1 AND is_active=TRUE`, [caseId]);
    if (!cr.length) return res.status(404).json({ error: 'case_not_found', message: 'Кейс не найден' });
    const c = cr[0];
    const { rows: items } = await query(
      `SELECT ci.drop_chance, it.id as item_id, it.name, it.price_coins, it.rarity, it.collection, it.image_asset, it.image_url
         FROM case_items ci JOIN items it ON it.id=ci.item_id
        WHERE ci.case_id=$1 ORDER BY ci.drop_chance DESC`,
      [caseId]
    );
    let daily = null;
    if (caseId === 'case_daily') {
      const { rows: dc } = await query(`SELECT COUNT(*)::int as cnt FROM case_openings WHERE user_id=$1 AND case_id=$2 AND created_at >= CURRENT_DATE`, [req.user.id, caseId]);
      const used = dc[0].cnt;
      const { rows: nr } = await query(`SELECT (CURRENT_DATE + interval '1 day')::timestamptz as next_reset`);
      daily = { used, remaining: Math.max(0, 10 - used), next_reset: nr[0].next_reset };
    }
    res.json({
      case: {
        id: c.id,
        name: c.name,
        price_nc: Number(c.price_nc),
        image_asset: c.image_asset ? `assets/case/${c.image_asset}` : null,
      },
      items: items.map((r) => ({
        item_id: r.item_id,
        name: r.name,
        price_coins: Number(r.price_coins),
        rarity: r.rarity,
        collection: r.collection,
        image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
        image_url: r.image_url,
        drop_chance: Number(r.drop_chance),
      })),
      ...(daily ? { daily } : {}),
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/cases/:id/open — открыть 1..10 кейсов
casesRouter.post('/:id/open', requireAuth, async (req, res, next) => {
  try {
    const caseId = String(req.params.id);
    let count = parseInt(req.body.count, 10);
    if (!count || isNaN(count)) count = 1;
    if (count < 1) count = 1;
    if (count > 10) count = 10;

    const result = await withTransaction(async (client) => {
      // блокируем пользователя
      const uRes = await client.query(`SELECT id, balance_nc, boost_x2_until, boost_x4_until FROM users WHERE id=$1 FOR UPDATE`, [req.user.id]);
      if (!uRes.rows.length) throw new Error('user_not_found');
      const user = uRes.rows[0];

      const cRes = await client.query(`SELECT id, name, price_nc FROM cases WHERE id=$1 AND is_active=TRUE`, [caseId]);
      if (!cRes.rows.length) return { error: 'case_not_found' };
      const c = cRes.rows[0];
      const priceOne = Number(c.price_nc);
      const totalPrice = priceOne * count;

      // лимиты — ежедневный теперь 10/день с счётчиком до сброса
      if (caseId === 'case_daily') {
        const { rows } = await client.query(
          `SELECT COUNT(*)::int as cnt FROM case_openings WHERE user_id=$1 AND case_id=$2 AND created_at >= CURRENT_DATE`,
          [req.user.id, caseId]
        );
        const used = rows[0].cnt;
        const remaining = 10 - used;
        if (remaining <= 0) {
          const { rows: nr } = await client.query(`SELECT (CURRENT_DATE + interval '1 day')::timestamptz as next_reset`);
          return { error: 'daily_limit', message: 'Дневной лимит 10/день исчерпан', remaining: 0, next_reset: nr[0].next_reset };
        }
        if (count > remaining) {
          return { error: 'daily_limit', message: `Осталось ${remaining} открытий сегодня`, remaining, used };
        }
      }

      if (totalPrice > 0 && Number(user.balance_nc) < totalPrice) {
        return { error: 'insufficient_nc', message: 'Недостаточно NC' };
      }

      let { rows: caseItems } = await client.query(
        `SELECT ci.item_id, ci.drop_chance, it.name, it.price_coins, it.rarity, it.collection, it.image_asset, it.image_url
           FROM case_items ci JOIN items it ON it.id=ci.item_id
          WHERE ci.case_id=$1 ORDER BY ci.drop_chance DESC`,
        [caseId]
      );
      if (!caseItems.length) return { error: 'case_empty', message: 'В кейсе нет предметов' };

      // Ивенты x2/x4 — увеличиваем шанс на крутые призы (глобальные + персональные)
      try {
        const ev = await activeEvents();
        // персональные бусты из Shop
        const now = new Date();
        const pX4 = user.boost_x4_until && new Date(user.boost_x4_until) > now;
        const pX2 = user.boost_x2_until && new Date(user.boost_x2_until) > now;
        if (pX4) ev.events.find((e) => e.key === 'x4').active = true;
        else if (pX2) ev.events.find((e) => e.key === 'x2').active = true;
        const mult = luckMultiplier(ev);
        if (mult > 1) {
          caseItems = caseItems.map((it) => {
            let boost = 1;
            if (it.rarity === 'legendary') boost = mult === 4 ? 2.5 : 2.0;
            else if (it.rarity === 'epic') boost = mult === 4 ? 2.0 : 1.6;
            else if (it.rarity === 'rare') boost = mult === 4 ? 1.5 : 1.3;
            return { ...it, drop_chance: Number(it.drop_chance) * boost };
          });
          // нормализуем к 100%
          const sum = caseItems.reduce((s, it) => s + Number(it.drop_chance), 0);
          caseItems = caseItems.map((it) => ({ ...it, drop_chance: (Number(it.drop_chance) / sum) * 100 }));
        }
      } catch (_) {}

      // списание
      let balanceNc = Number(user.balance_nc);
      if (totalPrice > 0) {
        balanceNc = await applyNcBalance(client, req.user.id, -totalPrice, 'case_open', c.id);
      }

      const won = [];
      for (let i = 0; i < count; i++) {
        const roll = crypto.randomInt(0, 1000000) / 10000; // 0..100 with 4 decimals
        const picked = pickByChance(caseItems, roll);
        const invRes = await client.query(
          `INSERT INTO inventory (user_id, item_id, status) VALUES ($1,$2,'open') RETURNING id`,
          [req.user.id, picked.item_id]
        );
        const inventoryId = invRes.rows[0].id;
        await client.query(
          `INSERT INTO case_openings (user_id, case_id, item_id, inventory_id, price_paid, roll)
           VALUES ($1,$2,$3,$4,$5,$6)`,
          [req.user.id, caseId, picked.item_id, inventoryId, priceOne, roll.toFixed(3)]
        );
        won.push({
          inventory_id: inventoryId,
          item_id: picked.item_id,
          name: picked.name,
          price_coins: Number(picked.price_coins),
          rarity: picked.rarity,
          collection: picked.collection,
          image_asset: picked.image_asset ? `assets/gifts/${picked.image_asset}` : null,
          image_url: picked.image_url,
          drop_chance: Number(picked.drop_chance),
          roll: Number(roll.toFixed(3)),
        });
      }

      // для ежедневного — считаем остаток после открытия
      let dailyMeta = null;
      if (caseId === 'case_daily') {
        const { rows } = await client.query(`SELECT COUNT(*)::int as cnt FROM case_openings WHERE user_id=$1 AND case_id=$2 AND created_at >= CURRENT_DATE`, [req.user.id, caseId]);
        const used = rows[0].cnt;
        const remaining = Math.max(0, 10 - used);
        const { rows: nr } = await client.query(`SELECT (CURRENT_DATE + interval '1 day')::timestamptz as next_reset`);
        dailyMeta = { daily_used: used, daily_remaining: remaining, next_reset: nr[0].next_reset };
      }
      return {
        won,
        balance_nc: balanceNc,
        balance_coins: null,
        price_paid: totalPrice,
        ...(dailyMeta || {}),
      };
    });

    if (result.error === 'case_not_found') return res.status(404).json({ error: 'case_not_found', message: 'Кейс не найден' });
    if (result.error === 'case_empty') return res.status(400).json({ error: 'case_empty', message: 'Кейс пуст' });
    if (result.error === 'insufficient_nc') return res.status(400).json({ error: 'insufficient_nc', message: result.message });
    if (result.error === 'daily_limit') return res.status(400).json(result);
    if (result.error) return res.status(400).json(result);

    try { await incDailyProgress(req.user.id, 'case_open', result.won.length); } catch (_) {}
    res.json(result);
  } catch (err) {
    next(err);
  }
});

// GET /api/cases/history/me — последние открытия (для дебага)
casesRouter.get('/history/me', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT co.id, co.case_id, co.item_id, co.price_paid, co.roll, co.created_at,
              it.name, it.price_coins, it.rarity
         FROM case_openings co JOIN items it ON it.id=co.item_id
        WHERE co.user_id=$1 ORDER BY co.created_at DESC LIMIT 30`,
      [req.user.id]
    );
    res.json({ history: rows });
  } catch (err) {
    next(err);
  }
});
