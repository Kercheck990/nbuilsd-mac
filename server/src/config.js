import 'dotenv/config';

const bool = (v, def = false) =>
  v === undefined ? def : ['1', 'true', 'yes', 'on'].includes(String(v).toLowerCase());

export const config = {
  port: Number(process.env.PORT || 8080),
  env: process.env.NODE_ENV || 'development',
  publicUrl: process.env.PUBLIC_URL || 'http://localhost:8080',

  db: {
    url: process.env.DATABASE_URL,
    ssl: bool(process.env.DATABASE_SSL, false),
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-insecure-secret-change-me',
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  },

  mail: {
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 465),
    secure: bool(process.env.SMTP_SECURE, true),
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    from: process.env.MAIL_FROM || 'NFT-Grader <no-reply@localhost>',
    devLog: bool(process.env.MAIL_DEV_LOG, true),
  },

  // ---------------------------------------------------------------
  // ПРАВИЛА ИГРЫ
  // Эти значения обязаны совпадать с lib/core/constants/app_constants.dart.
  // Сервер — источник правды: даже если клиент подменят, раунд с шансом
  // выше 75% будет отклонён здесь.
  // ---------------------------------------------------------------
  game: {
    minChancePercent: 1,
    maxChancePercent: 75,
    // сколько монет возвращается при продаже предмета, 1.0 = полная цена
    sellRatio: 1.0,
  },

  payments: {
    coinsPerUnit: Number(process.env.COINS_PER_UNIT || 100),
    currency: process.env.CURRENCY || 'USD',
    minCoins: 100,
    stripe: {
      secretKey: process.env.STRIPE_SECRET_KEY,
      webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
    },
    cryptoPay: {
      token: process.env.CRYPTO_PAY_TOKEN,
      asset: process.env.CRYPTO_PAY_ASSET || 'USDT',
      webhookSecret: process.env.CRYPTO_PAY_WEBHOOK_SECRET,
    },
    telegram: {
      botToken: process.env.TELEGRAM_BOT_TOKEN,
    },
  },
};

if (!config.db.url) {
  console.warn('⚠ DATABASE_URL не задан — сервер не сможет обратиться к базе.');
}
if (config.jwt.secret.startsWith('dev-insecure') && config.env === 'production') {
  throw new Error('JWT_SECRET обязателен в production.');
}
