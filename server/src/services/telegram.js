import { config } from '../config.js';

const botToken = () => config.payments.telegram.botToken;

/// Отправка сообщения через Bot API без внешних зависимостей (Node 20+: fetch).
export async function tgSendMessage(chatId, text) {
  if (!botToken()) return { ok: false, skipped: true };
  const res = await fetch(`https://api.telegram.org/bot${botToken()}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' }),
  });
  return res.json();
}

/// Ответ на webhook: Telegram ждёт 200 быстро, иначе дублирует апдейты.
export function tgOk(res) {
  res.json({ ok: true });
}
