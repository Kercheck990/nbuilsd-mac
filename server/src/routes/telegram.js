import express from 'express';

import { query } from '../db.js';
import { tgOk, tgSendMessage } from '../services/telegram.js';

/// Webhook Telegram-бота:apo BotFather → https://<host>/api/telegram/hook
/// Игрок отправляет боту 6-значный код из приложения — привязываем chat_id.
export const telegramRouter = express.Router();

function parseBody(req) {
  // Сюда роут монтируется ПОСЛЕ express.json, тело уже распарсено.
  // Но вебхуки платежей висят на raw-парсере — этот путь отдельный.
  if (req.body && typeof req.body === 'object' && !(req.body instanceof Buffer)) {
    return req.body;
  }
  try {
    const raw = req.body instanceof Buffer ? req.body.toString('utf8') : String(req.body || '');
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

telegramRouter.post('/hook', async (req, res) => {
  tgOk(res);
  try {
    const secret = process.env.TELEGRAM_WEBHOOK_SECRET;
    if (secret && req.query.secret !== secret && req.headers['x-telegram-secret'] !== secret) {
      return;
    }
    const update = parseBody(req);
    const msg = update.message || update.edited_message;
    if (!msg || !msg.chat || !msg.text) return;

    const chatId = String(msg.chat.id);
    const text = String(msg.text).trim();
    const username = msg.from?.username ? `@${msg.from.username}` : null;

    if (/^\/start/.test(text)) {
      await tgSendMessage(
        chatId,
        `Привет! Это бот <b>NFT-Grader</b>.\n\n` +
          `Чтобы привязать аккаунт, возьми 6-значный код в приложении ` +
          `(Настройки → Telegram) и отправь его сюда следующим сообщением.`
      );
      return;
    }

    if (!/^\d{6}$/.test(text)) {
      await tgSendMessage(chatId, `Отправь 6-значный код из приложения, и я привяжу аккаунт.`);
      return;
    }

    const { rows } = await query(
      `SELECT user_id FROM tg_codes WHERE code = $1 AND expires_at > now()`,
      [text]
    );
    if (!rows.length) {
      await tgSendMessage(chatId, `Код неверный или просрочен. Возьми свежий в приложении.`);
      return;
    }

    await query(
      `UPDATE users SET telegram_id = $2, telegram_username = $3 WHERE id = $1`,
      [rows[0].user_id, chatId, username]
    );
    await query(`DELETE FROM tg_codes WHERE code = $1`, [text]);
    await tgSendMessage(chatId, `Готово! Аккаунт привязан. Уведомления и 2FA-коды будут приходить сюда.`);
  } catch (err) {
    console.error('TG webhook:', err.message);
  }
});
