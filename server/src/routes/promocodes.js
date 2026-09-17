import express from 'express';

import { applyBalance, query, withTransaction } from '../db.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';

export const promocodesRouter = express.Router();

function bad(res, code, message, status = 400) {
  return res.status(status).json({ error: code, message });
}

/// POST /api/promocodes/redeem — ввести промокод при пополнении.
promocodesRouter.post('/redeem', requireAuth, async (req, res, next) => {
  try {
    const code = String(req.body.code || '').trim().toUpperCase();
    if (!code) return bad(res, 'no_code', 'Введите промокод');

    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT * FROM promocodes WHERE code = $1 FOR UPDATE`,
        [code]
      );
      if (!rows.length) return { error: 'invalid_code' };
      const promo = rows[0];
      if (!promo.is_active) return { error: 'inactive' };
      if (promo.expires_at && new Date(promo.expires_at) < new Date()) {
        return { error: 'expired' };
      }
      if (promo.max_uses != null && promo.used_count >= promo.max_uses) {
        return { error: 'exhausted' };
      }

      const used = await client.query(
        `SELECT 1 FROM promocode_redemptions WHERE user_id = $1 AND code_id = $2`,
        [req.user.id, promo.id]
      );
      if (used.rows.length) return { error: 'already_used' };

      await client.query(
        `INSERT INTO promocode_redemptions (user_id, code_id) VALUES ($1, $2)`,
        [req.user.id, promo.id]
      );
      await client.query(
        `UPDATE promocodes SET used_count = used_count + 1 WHERE id = $1`,
        [promo.id]
      );
      const balance = await applyBalance(
        client,
        req.user.id,
        promo.coins,
        'promocode',
        promo.code
      );
      return { coins: promo.coins, balance };
    });

    if (result.error === 'invalid_code') return bad(res, 'invalid_code', 'Такого промокода нет', 404);
    if (result.error === 'inactive') return bad(res, 'inactive', 'Промокод отключён');
    if (result.error === 'expired') return bad(res, 'expired', 'Промокод просрочен');
    if (result.error === 'exhausted') return bad(res, 'exhausted', 'Лимит использований исчерпан');
    if (result.error === 'already_used') {
      return bad(res, 'already_used', 'Вы уже использовали этот промокод');
    }
    res.json({ ok: true, coins: result.coins, balance_coins: result.balance });
  } catch (err) {
    next(err);
  }
});

/// GET /api/promocodes/admin — список (админ).
promocodesRouter.get('/admin', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT * FROM promocodes ORDER BY created_at DESC LIMIT 100`
    );
    res.json({ promocodes: rows });
  } catch (err) {
    next(err);
  }
});

/// POST /api/promocodes/admin — создать/обновить (админ).
promocodesRouter.post('/admin', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const code = String(req.body.code || '').trim().toUpperCase().slice(0, 32);
    const coins = Math.floor(Number(req.body.coins) || 0);
    const maxUses =
      req.body.max_uses == null || req.body.max_uses === ''
        ? null
        : Math.max(1, Math.floor(Number(req.body.max_uses)));
    const isActive = req.body.is_active !== false;
    const expiresAt = req.body.expires_at ? new Date(req.body.expires_at) : null;

    if (!code) return bad(res, 'no_code', 'Укажите код');
    if (coins <= 0) return bad(res, 'bad_coins', 'Сумма должна быть больше нуля');

    const { rows } = await query(
      `INSERT INTO promocodes (code, coins, max_uses, is_active, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (code) DO UPDATE
         SET coins = EXCLUDED.coins, max_uses = EXCLUDED.max_uses,
             is_active = EXCLUDED.is_active, expires_at = EXCLUDED.expires_at
       RETURNING *`,
      [code, coins, maxUses, isActive, expiresAt]
    );
    res.status(201).json({ promocode: rows[0] });
  } catch (err) {
    next(err);
  }
});
