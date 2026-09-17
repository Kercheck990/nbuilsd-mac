import express from 'express';

import { config } from '../config.js';
import { applyBalance, query, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import {
  coinsToMoney,
  createCryptoInvoice,
  createStarsInvoice,
  createStripeInvoice,
  verifyCryptoPaySignature,
  verifyStripeWebhook,
} from '../services/payments.js';

export const paymentsRouter = express.Router();

// ===================================================================
// ЗАЧИСЛЕНИЕ
// Единственное место, где баланс растёт от платежа. Идемпотентно:
// повторный вебхук с тем же платежом ничего не начислит второй раз,
// потому что строка блокируется FOR UPDATE и проверяется флаг credited.
// ===================================================================
async function creditPayment(paymentId, rawPayload = null) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT * FROM payments WHERE id = $1 FOR UPDATE`,
      [paymentId]
    );
    if (!rows.length) return { ok: false, reason: 'not_found' };
    const payment = rows[0];

    if (payment.credited) return { ok: true, already: true, payment };

    const balance = await applyBalance(
      client,
      payment.user_id,
      payment.amount_coins,
      'topup',
      payment.id
    );

    await client.query(
      `UPDATE payments
          SET status = 'paid', credited = TRUE, paid_at = now(),
              raw_payload = COALESCE($2, raw_payload)
        WHERE id = $1`,
      [payment.id, rawPayload ? JSON.stringify(rawPayload) : null]
    );

    return { ok: true, payment, balance };
  });
}

async function markFailed(paymentId, status = 'failed') {
  await query(`UPDATE payments SET status = $2 WHERE id = $1 AND credited = FALSE`, [
    paymentId,
    status,
  ]);
}

// ===================================================================
// POST /api/payments/create — создать счёт
// ===================================================================
paymentsRouter.post('/create', requireAuth, async (req, res, next) => {
  try {
    const coins = Math.floor(Number(req.body.amount_coins) || 0);
    const provider = ['card', 'crypto', 'stars'].includes(req.body.provider)
      ? req.body.provider
      : 'card';

    if (coins < config.payments.minCoins) {
      return res.status(400).json({
        error: 'amount_too_small',
        message: `Минимум ${config.payments.minCoins} монет`,
      });
    }

    // Сначала заводим платёж в своей базе — так у нас есть id, который
    // можно передать провайдеру и получить обратно в вебхуке.
    const inserted = await query(
      `INSERT INTO payments (user_id, provider, amount_coins, amount_money, currency)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [req.user.id, provider, coins, coinsToMoney(coins), config.payments.currency]
    );
    const paymentId = inserted.rows[0].id;

    let invoice;
    try {
      if (provider === 'card') {
        invoice = await createStripeInvoice({
          paymentId,
          coins,
          email: req.user.email,
        });
      } else if (provider === 'crypto') {
        invoice = await createCryptoInvoice({ paymentId, coins });
      } else {
        invoice = await createStarsInvoice({ paymentId, coins });
      }
    } catch (err) {
      await markFailed(paymentId);
      return res.status(502).json({
        error: 'provider_error',
        message: `Провайдер не настроен или недоступен: ${err.message}`,
      });
    }

    await query(
      `UPDATE payments SET external_id = $2, pay_url = $3 WHERE id = $1`,
      [paymentId, invoice.externalId, invoice.payUrl]
    );

    res.json({
      payment_id: paymentId,
      pay_url: invoice.payUrl,
      amount_coins: coins,
      amount_money: invoice.amountMoney,
      currency: config.payments.currency,
      status: 'pending',
    });
  } catch (err) {
    next(err);
  }
});

// ===================================================================
// GET /api/payments/:id — статус (клиент опрашивает после оплаты)
// ===================================================================
paymentsRouter.get('/:id', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await query(
      `SELECT p.id, p.status, p.amount_coins, p.provider, p.created_at, p.paid_at,
              u.balance_coins
         FROM payments p
         JOIN users u ON u.id = p.user_id
        WHERE p.id = $1 AND p.user_id = $2`,
      [req.params.id, req.user.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'not_found', message: 'Платёж не найден' });
    }
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

// ===================================================================
// ВЕБХУКИ
// Тело этих маршрутов парсится как raw (см. index.js) — подпись
// считается по исходным байтам, иначе проверка не сойдётся.
// ===================================================================

/// Stripe: dashboard → Webhooks → добавить
/// {PUBLIC_URL}/api/payments/webhook/stripe, событие checkout.session.completed
paymentsRouter.post('/webhook/stripe', async (req, res) => {
  try {
    const event = await verifyStripeWebhook(req.body, req.headers['stripe-signature']);

    if (event.type === 'checkout.session.completed') {
      const paymentId = event.data.object.metadata?.payment_id;
      if (paymentId) await creditPayment(paymentId, event.data.object);
    } else if (
      event.type === 'checkout.session.expired' ||
      event.type === 'payment_intent.payment_failed'
    ) {
      const paymentId = event.data.object.metadata?.payment_id;
      if (paymentId) await markFailed(paymentId, 'expired');
    }
    res.json({ received: true });
  } catch (err) {
    console.error('Stripe webhook:', err.message);
    res.status(400).json({ error: 'invalid_signature' });
  }
});

/// Crypto Pay: в @CryptoBot → My Apps → Webhooks укажите
/// {PUBLIC_URL}/api/payments/webhook/crypto
paymentsRouter.post('/webhook/crypto', async (req, res) => {
  try {
    const signature = req.headers['crypto-pay-api-signature'];
    const valid = await verifyCryptoPaySignature(req.body, signature);
    if (!valid) return res.status(401).json({ error: 'invalid_signature' });

    const update = JSON.parse(req.body.toString('utf8'));
    if (update.update_type === 'invoice_paid') {
      const paymentId = update.payload?.payload;
      if (paymentId) await creditPayment(paymentId, update);
    }
    res.json({ received: true });
  } catch (err) {
    console.error('CryptoPay webhook:', err.message);
    res.status(400).json({ error: 'bad_request' });
  }
});

/// Telegram Stars: ваш бот получает апдейт с successful_payment и
/// пересылает его сюда. Защита — секрет в заголовке
/// X-Telegram-Bot-Api-Secret-Token (задаётся при setWebhook).
paymentsRouter.post('/webhook/stars', async (req, res) => {
  try {
    const secret = req.headers['x-telegram-bot-api-secret-token'];
    if (config.payments.telegram.botToken && secret !== config.payments.telegram.botToken) {
      return res.status(401).json({ error: 'invalid_signature' });
    }
    const update = JSON.parse(req.body.toString('utf8'));
    const payment = update.message?.successful_payment;
    if (payment?.invoice_payload) {
      await creditPayment(payment.invoice_payload, update);
    }
    res.json({ received: true });
  } catch (err) {
    console.error('Stars webhook:', err.message);
    res.status(400).json({ error: 'bad_request' });
  }
});
