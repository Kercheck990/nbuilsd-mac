import express from 'express';
import { applyBalance, query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

export const shopRouter = express.Router();
shopRouter.use(requireAuth);

// Prices for boosts in NFC (balance_coins)
const BOOSTS = {
  blessing: { price: 50, title: 'Благословение', body: 'Сейв 50% в апгрейдере на 15 мин' },
  x2: { price: 30, title: 'x2 Удача', body: 'x2 шанс в кейсах и апгрейдере на 15 мин' },
  x4: { price: 70, title: 'x4 Удача', body: 'x4 шанс на 15 мин' },
};

// POST /api/shop/buy-blessing (оплата NFC)
shopRouter.post('/buy-blessing', async (req, res, next) => {
  try {
    const cfg = BOOSTS.blessing;
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(`SELECT balance_coins FROM users WHERE id=$1 FOR UPDATE`, [req.user.id]);
      if (rows[0].balance_coins < cfg.price) return { error: 'insufficient_funds' };
      const newBal = await applyBalance(client, req.user.id, -cfg.price, 'shop_blessing');
      // set per-user boost 15 min
      await client.query(
        `UPDATE users SET boost_saves_until = now() + interval '15 minutes' WHERE id=$1`,
        [req.user.id]
      );
      await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'balance','Покупка в Shop','Вы купили ${cfg.title} за ${cfg.price} NFC на 15 минут')`, [req.user.id]);
      return { balance_coins: newBal, balance_nc: rows[0].balance_nc };
    });
    if (result.error) return res.status(400).json({ error: result.error });
    res.json(result);
  } catch (err) { next(err); }
});

// POST /api/shop/buy-luck {mult:2|4} (оплата NFC)
shopRouter.post('/buy-luck', async (req, res, next) => {
  try {
    const mult = parseInt(req.body.mult, 10) === 4 ? 4 : 2;
    const key = mult === 4 ? 'x4' : 'x2';
    const cfg = BOOSTS[key];
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(`SELECT balance_coins FROM users WHERE id=$1 FOR UPDATE`, [req.user.id]);
      if (rows[0].balance_coins < cfg.price) return { error: 'insufficient_funds' };
      const newBal = await applyBalance(client, req.user.id, -cfg.price, `shop_${key}`);
      const col = mult === 4 ? 'boost_x4_until' : 'boost_x2_until';
      await client.query(`UPDATE users SET ${col} = now() + interval '15 minutes' WHERE id=$1`, [req.user.id]);
      await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'balance','Покупка в Shop','Вы купили ${cfg.title} за ${cfg.price} NFC на 15 минут')`, [req.user.id]);
      return { balance_coins: newBal };
    });
    if (result.error) return res.status(400).json({ error: result.error });
    res.json(result);
  } catch (err) { next(err); }
});

// POST /api/shop/buy/:itemId — покупка гифта за NFC
shopRouter.post('/buy/:itemId', async (req, res, next) => {
  try {
    const itemId = String(req.params.itemId);
    const result = await withTransaction(async (client) => {
      const { rows: items } = await client.query(`SELECT id, price_coins, name FROM items WHERE id=$1 AND is_active=TRUE`, [itemId]);
      if (!items.length) return { error: 'item_not_found' };
      const item = items[0];
      const priceNfc = Number(item.price_coins);
      const { rows: users } = await client.query(`SELECT balance_coins FROM users WHERE id=$1 FOR UPDATE`, [req.user.id]);
      if (users[0].balance_coins < priceNfc) return { error: 'insufficient_funds' };
      const newBal = await applyBalance(client, req.user.id, -priceNfc, 'shop_item', itemId);
      const inv = await client.query(`INSERT INTO inventory (user_id, item_id, status) VALUES ($1,$2,'open') RETURNING id`, [req.user.id, itemId]);
      await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'balance','Покупка в магазине','Вы купили ${item.name} за ${priceNfc} NFC')`, [req.user.id]);
      return { ok: true, balance_coins: newBal, balance_nc: users[0].balance_nc, inventory_id: inv.rows[0].id };
    });
    if (result.error) return res.status(400).json({ error: result.error });
    res.json(result);
  } catch (err) { next(err); }
});

// GET /api/shop/boosts — active boosts for user
shopRouter.get('/boosts', async (req, res, next) => {
  try {
    const { rows } = await query(`SELECT boost_saves_until, boost_x2_until, boost_x4_until FROM users WHERE id=$1`, [req.user.id]);
    res.json(rows[0] || {});
  } catch (err) { next(err); }
});
