import express from 'express';
import { applyBalance, query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

export const itemsRouter = express.Router();

/// GET /api/items — каталог целей апгрейда.
/// image_asset — имя файла в assets/gifts/ у клиента.
itemsRouter.get('/', async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT id, name, price_coins, rarity, collection, image_asset, image_url
         FROM items
        WHERE is_active = TRUE
        ORDER BY price_coins ASC`
    );
    res.json({
      items: rows.map((r) => ({
        ...r,
        // Клиент ждёт путь относительно корня проекта.
        image_asset: r.image_asset ? `assets/gifts/${r.image_asset}` : null,
      })),
    });
  } catch (err) {
    next(err);
  }
});

/// POST /api/items/buy — покупка предмета из магазина за монеты.
/// Предмет сразу падает в инвентарь.
itemsRouter.post('/buy', requireAuth, async (req, res, next) => {
  try {
    const itemId = String(req.body.item_id || '');
    if (!itemId) {
      return res.status(400).json({ error: 'no_item', message: 'Не выбран предмет' });
    }
    const result = await withTransaction(async (client) => {
      const itemRes = await client.query(
        `SELECT id, name, price_coins FROM items WHERE id = $1 AND is_active = TRUE`,
        [itemId]
      );
      if (!itemRes.rows.length) return { error: 'item_not_found' };
      const item = itemRes.rows[0];

      const userRes = await client.query(
        `SELECT balance_coins FROM users WHERE id = $1 FOR UPDATE`,
        [req.user.id]
      );
      if (userRes.rows[0].balance_coins < item.price_coins) {
        return { error: 'insufficient_funds' };
      }

      const balance = await applyBalance(client, req.user.id, -item.price_coins, 'shop_buy', item.id);
      const invRes = await client.query(
        `INSERT INTO inventory (user_id, item_id, status) VALUES ($1, $2, 'open') RETURNING id`,
        [req.user.id, item.id]
      );
      return { balance, inventory_id: invRes.rows[0].id, item };
    });

    if (result.error === 'item_not_found') {
      return res.status(404).json({ error: 'item_not_found', message: 'Предмет не найден' });
    }
    if (result.error === 'insufficient_funds') {
      return res.status(400).json({ error: 'insufficient_funds', message: 'Недостаточно монет' });
    }
    res.json({ ok: true, balance_coins: result.balance, inventory_id: result.inventory_id });
  } catch (err) {
    next(err);
  }
});
