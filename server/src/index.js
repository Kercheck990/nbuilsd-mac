import cors from 'cors';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

import { config } from './config.js';
import { pool } from './db.js';
import { adminRouter } from './routes/admin.js';
import { authRouter } from './routes/auth.js';
import { casesRouter } from './routes/cases.js';
import { dailyRouter, dailyAdminRouter } from './routes/daily.js';
import { itemsRouter } from './routes/items.js';
import { leaderboardRouter } from './routes/leaderboard.js';
import { notificationsRouter } from './routes/notifications.js';
import { paymentsRouter } from './routes/payments.js';
import { shopRouter } from './routes/shop.js';
import { promocodesRouter } from './routes/promocodes.js';
import { telegramRouter } from './routes/telegram.js';
import { ticketsRouter } from './routes/tickets.js';
import { tradesRouter } from './routes/trades.js';
import { upgradeRouter } from './routes/upgrade.js';
import { userRouter } from './routes/user.js';

const app = express();
app.set('trust proxy', 1);
app.use(cors());
// Статика для загруженной музыки: /music/<file> -> server/public/music/
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const musicPublicDir = path.join(__dirname, '../public/music');
try { fs.mkdirSync(musicPublicDir, { recursive: true }); } catch {}
app.use('/music', express.static(musicPublicDir));
app.use('/public', express.static(path.join(__dirname, '../public')));

// ВАЖНО: вебхуки должны получить СЫРОЕ тело, иначе подпись провайдера
// не сойдётся. Поэтому raw-парсер подключается до express.json().
app.use('/api/payments/webhook', express.raw({ type: '*/*', limit: '1mb' }));
app.use(express.json({ limit: '256kb' }));

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, env: config.env });
  } catch {
    res.status(503).json({ ok: false, error: 'db_unavailable' });
  }
});

// Публичные правила игры — клиент может свериться, что потолок тот же.
app.get('/api/config', (req, res) => {
  res.json({
    min_chance_percent: config.game.minChancePercent,
    max_chance_percent: config.game.maxChancePercent,
    coins_per_unit: config.payments.coinsPerUnit,
    currency: config.payments.currency,
    min_topup_coins: config.payments.minCoins,
  });
});

app.use('/api/auth', authRouter);
app.use('/api/items', itemsRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api/cases', casesRouter);
app.use('/api/upgrade', upgradeRouter);
app.use('/api/leaderboard', leaderboardRouter);
app.use('/api/trades', tradesRouter);
app.use('/api/tickets', ticketsRouter);
app.use('/api/promocodes', promocodesRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/daily', dailyRouter);
app.use('/api', dailyAdminRouter);
app.use('/api/shop', shopRouter);
app.use('/api/admin', adminRouter);
app.use('/api/telegram', telegramRouter);
app.use('/api', userRouter); // /api/me, /api/inventory, /api/history, ...

// Страницы возврата после оплаты (Stripe требует валидные URL).
app.get('/pay/:result', (req, res) => {
  const ok = req.params.result === 'success';
  res.type('html').send(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
     <body style="margin:0;display:grid;place-items:center;height:100vh;background:#0b0b0f;color:#fff;font-family:system-ui">
       <div style="text-align:center">
         <div style="font-size:52px">${ok ? '✅' : '❌'}</div>
         <h2>${ok ? 'Оплата получена' : 'Оплата отменена'}</h2>
         <p style="color:#9CA3AF">${ok ? 'Можете вернуться в приложение — баланс обновится автоматически.' : 'Вернитесь в приложение и попробуйте снова.'}</p>
       </div>
     </body>`
  );
});

app.use((req, res) => {
  res.status(404).json({ error: 'not_found', message: 'Маршрут не найден' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Необработанная ошибка:', err);
  if (err.type === 'entity.parse.failed' || err.status === 400 || err.statusCode === 400) {
    return res.status(400).json({ error: 'bad_request', message: 'Некорректный JSON' });
  }
  const status = err.status || err.statusCode || 500;
  const code = err.code || (status === 400 ? 'bad_request' : 'internal_error');
  res.status(status).json({ error: code, message: err.message || 'Внутренняя ошибка сервера' });
});

const server = app.listen(config.port, () => {
  console.log(`NFT-Grader API слушает порт ${config.port} (${config.env})`);
});

// Аккуратное завершение, чтобы не рвать открытые транзакции.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
  });
}
