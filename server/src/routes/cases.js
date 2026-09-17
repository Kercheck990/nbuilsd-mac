import express from 'express';
import crypto from 'node:crypto';
import { applyNcBalance, query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

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
      const uRes = await client.query(`SELECT id, balance_nc FROM users WHERE id=$1 FOR UPDATE`, [req.user.id]);
      if (!uRes.rows.length) throw new Error('user_not_found');
      const user = uRes.rows[0];

      const cRes = await client.query(`SELECT id, name, price_nc FROM cases WHERE id=$1 AND is_active=TRUE`, [caseId]);
      if (!cRes.rows.length) return { error: 'case_not_found' };
      const c = cRes.rows[0];
      const priceOne = Number(c.price_nc);
      const totalPrice = priceOne * count;

      // лимиты
      if (caseId === 'case_daily') {
        const { rows } = await client.query(
          `SELECT 1 FROM case_openings WHERE user_id=$1 AND case_id=$2 AND created_at >= CURRENT_DATE LIMIT 1`,
          [req.user.id, caseId]
        );
        if (rows.length) return { error: 'daily_limit', message: 'Ежедневный кейс можно открыть раз в день' };
        if (count !== 1) return { error: 'daily_single', message: 'Ежедневный кейс — только 1 за раз' };
      }

      if (totalPrice > 0 && Number(user.balance_nc) < totalPrice) {
        return { error: 'insufficient_nc', message: 'Недостаточно NC' };
      }

      const { rows: caseItems } = await client.query(
        `SELECT ci.item_id, ci.drop_chance, it.name, it.price_coins, it.rarity, it.collection, it.image_asset, it.image_url
           FROM case_items ci JOIN items it ON it.id=ci.item_id
          WHERE ci.case_id=$1 ORDER BY ci.drop_chance DESC`,
        [caseId]
      );
      if (!caseItems.length) return { error: 'case_empty', message: 'В кейсе нет предметов' };

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

      return {
        won,
        balance_nc: balanceNc,
        balance_coins: null, // клиент возьмет из /api/me если нужно
        price_paid: totalPrice,
      };
    });

    if (result.error === 'case_not_found') return res.status(404).json({ error: 'case_not_found', message: 'Кейс не найден' });
    if (result.error === 'case_empty') return res.status(400).json({ error: 'case_empty', message: 'Кейс пуст' });
    if (result.error === 'insufficient_nc') return res.status(400).json({ error: 'insufficient_nc', message: result.message });
    if (result.error === 'daily_limit') return res.status(400).json({ error: 'daily_limit', message: result.message });
    if (result.error === 'daily_single') return res.status(400).json({ error: 'daily_single', message: result.message });
    if (result.error) return res.status(400).json(result);

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
