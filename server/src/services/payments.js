import { config } from '../config.js';

/// Монеты → деньги. Курс задаётся COINS_PER_UNIT в .env
/// (например 100 монет = 1 USD).
export function coinsToMoney(coins) {
  return Number((coins / config.payments.coinsPerUnit).toFixed(2));
}

// ===================================================================
// STRIPE — банковские карты
// ===================================================================
let stripeClient = null;
async function getStripe() {
  if (stripeClient) return stripeClient;
  if (!config.payments.stripe.secretKey) return null;
  const { default: Stripe } = await import('stripe');
  stripeClient = new Stripe(config.payments.stripe.secretKey);
  return stripeClient;
}

/// Создаёт Checkout Session. paymentId кладём в metadata — по нему
/// вебхук находит платёж в нашей базе.
export async function createStripeInvoice({ paymentId, coins, email }) {
  const stripe = await getStripe();
  if (!stripe) throw new Error('stripe_not_configured');

  const amount = coinsToMoney(coins);
  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    customer_email: email,
    line_items: [
      {
        price_data: {
          currency: config.payments.currency.toLowerCase(),
          product_data: { name: `${coins} монет NFT-Grader` },
          unit_amount: Math.round(amount * 100), // Stripe считает в центах
        },
        quantity: 1,
      },
    ],
    metadata: { payment_id: paymentId },
    success_url: `${config.publicUrl}/pay/success?id=${paymentId}`,
    cancel_url: `${config.publicUrl}/pay/cancel?id=${paymentId}`,
  });

  return { externalId: session.id, payUrl: session.url, amountMoney: amount };
}

export async function verifyStripeWebhook(rawBody, signature) {
  const stripe = await getStripe();
  if (!stripe) throw new Error('stripe_not_configured');
  return stripe.webhooks.constructEvent(
    rawBody,
    signature,
    config.payments.stripe.webhookSecret
  );
}

// ===================================================================
// CRYPTO PAY (@CryptoBot) — USDT / TON / BTC
// Документация: https://help.crypt.bot/crypto-pay-api
// ===================================================================
const CRYPTO_PAY_API = 'https://pay.crypt.bot/api';

async function cryptoPayCall(method, payload) {
  const res = await fetch(`${CRYPTO_PAY_API}/${method}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Crypto-Pay-API-Token': config.payments.cryptoPay.token,
    },
    body: JSON.stringify(payload),
  });
  const data = await res.json();
  if (!data.ok) {
    throw new Error(`crypto_pay_error: ${JSON.stringify(data.error)}`);
  }
  return data.result;
}

export async function createCryptoInvoice({ paymentId, coins }) {
  if (!config.payments.cryptoPay.token) throw new Error('cryptopay_not_configured');

  const amount = coinsToMoney(coins);
  const invoice = await cryptoPayCall('createInvoice', {
    asset: config.payments.cryptoPay.asset,
    amount: String(amount),
    description: `${coins} монет NFT-Grader`,
    // payload вернётся к нам в вебхуке — по нему находим платёж
    payload: paymentId,
    allow_comments: false,
    expires_in: 1800,
  });

  return {
    externalId: String(invoice.invoice_id),
    payUrl: invoice.bot_invoice_url || invoice.pay_url,
    amountMoney: amount,
  };
}

/// Подпись вебхука Crypto Pay: HMAC-SHA256 тела запроса ключом
/// SHA256(api_token). Считаем вручную, SDK не нужен.
export async function verifyCryptoPaySignature(rawBody, signature) {
  const crypto = await import('node:crypto');
  const secret = crypto.createHash('sha256').update(config.payments.cryptoPay.token).digest();
  const hmac = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  return hmac === signature;
}

// ===================================================================
// TELEGRAM STARS — оплата внутри Telegram-бота
// Ссылка создаётся методом createInvoiceLink, валюта XTR.
// Подтверждение приходит боту апдейтом successful_payment, который вы
// пересылаете на /api/payments/webhook/stars.
// ===================================================================
export async function createStarsInvoice({ paymentId, coins }) {
  const token = config.payments.telegram.botToken;
  if (!token) throw new Error('telegram_not_configured');

  // 1 звезда ≈ 0.013 USD; пересчитайте под свою экономику.
  const stars = Math.max(1, Math.round(coinsToMoney(coins) / 0.013));

  const res = await fetch(`https://api.telegram.org/bot${token}/createInvoiceLink`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      title: `${coins} монет`,
      description: 'Пополнение баланса NFT-Grader',
      payload: paymentId,
      currency: 'XTR',
      prices: [{ label: `${coins} монет`, amount: stars }],
    }),
  });
  const data = await res.json();
  if (!data.ok) throw new Error(`telegram_error: ${JSON.stringify(data.description)}`);

  return { externalId: paymentId, payUrl: data.result, amountMoney: coinsToMoney(coins) };
}
