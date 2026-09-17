import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { query } from '../db.js';

/// Проверяет Bearer-токен и кладёт пользователя в req.user.
export async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'unauthorized', message: 'Нет токена' });
  }
  try {
    const payload = jwt.verify(token, config.jwt.secret);
     const { rows } = await query(
      `SELECT id, email, nickname, avatar_url, locale, balance_coins, balance_nc,
              email_verified, is_banned, client_seed, is_admin, badges,
              telegram_id, telegram_username, tfa_enabled, playtime_seconds
         FROM users WHERE id = $1`,
      [payload.sub]
    );
    if (!rows.length) {
      return res.status(401).json({ error: 'unauthorized', message: 'Пользователь не найден' });
    }
    if (rows[0].is_banned) {
      return res.status(403).json({ error: 'banned', message: 'Аккаунт заблокирован' });
    }
    req.user = rows[0];
    next();
  } catch {
    return res.status(401).json({ error: 'invalid_token', message: 'Токен недействителен' });
  }
}

export function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
}

/// Требует права админа (после requireAuth).
export async function requireAdmin(req, res, next) {
  if (req.user && req.user.is_admin) return next();
  return res.status(403).json({ error: 'forbidden', message: 'Нужны права админа' });
}

/// Публичное представление пользователя (без хэша пароля).
export function publicUser(u) {
  return {
    id: u.id,
    email: u.email,
    nickname: u.nickname,
    avatar_url: u.avatar_url,
    locale: u.locale,
    balance_coins: Number(u.balance_coins),
    balance_nc: Number(u.balance_nc ?? 30),
    email_verified: u.email_verified,
    is_admin: !!u.is_admin,
    badges: u.badges || [],
    tfa_enabled: !!u.tfa_enabled,
    telegram_linked: !!u.telegram_id,
    telegram_username: u.telegram_username || null,
    playtime_seconds: Number(u.playtime_seconds || 0),
  };
}
