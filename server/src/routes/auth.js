import express from 'express';
import bcrypt from 'bcryptjs';
import rateLimit from 'express-rate-limit';

import { query, withTransaction } from '../db.js';
import { publicUser, requireAuth, signToken } from '../middleware/auth.js';
import { generateEmailCode, sha256 } from '../services/fairness.js';
import { sendVerificationCode } from '../services/mailer.js';

export const authRouter = express.Router();

const CODE_TTL_MINUTES = 10;
const MAX_CODE_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 60;

// Ограничения против перебора и спама письмами.
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests', message: 'Слишком много попыток' },
});
authRouter.use(strictLimiter);

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/;

function bad(res, code, message, status = 400) {
  return res.status(status).json({ error: code, message });
}

/// Создаёт новый код, гасит старые и отправляет письмо.
/// purpose: 'verify' (почта) или 'tfa' (второй фактор).
async function issueCode(userId, email, locale, purpose = 'verify') {
  const code = generateEmailCode();
  const hash = sha256(code);

  await withTransaction(async (client) => {
    // Старые неиспользованные коды больше не действуют.
    await client.query(
      `UPDATE email_codes SET consumed_at = now()
        WHERE user_id = $1 AND purpose = $2 AND consumed_at IS NULL`,
      [userId, purpose]
    );
    await client.query(
      `INSERT INTO email_codes (user_id, code_hash, purpose, expires_at)
       VALUES ($1, $2, $3, now() + ($4 || ' minutes')::interval)`,
      [userId, hash, purpose, String(CODE_TTL_MINUTES)]
    );
  });

  await sendVerificationCode(email, code, locale);
}

/// Проверяет 6-значный код заданного назначения. Возвращает 'ok' или код ошибки.
async function checkCode(userId, code, purpose) {
  const codeRes = await query(
    `SELECT * FROM email_codes
      WHERE user_id = $1 AND purpose = $2 AND consumed_at IS NULL
      ORDER BY created_at DESC LIMIT 1`,
    [userId, purpose]
  );
  if (!codeRes.rows.length) return 'code_expired';
  const record = codeRes.rows[0];
  if (new Date(record.expires_at) < new Date()) return 'code_expired';
  if (record.attempts >= MAX_CODE_ATTEMPTS) return 'code_expired';
  if (sha256(code) !== record.code_hash) {
    await query(`UPDATE email_codes SET attempts = attempts + 1 WHERE id = $1`, [
      record.id,
    ]);
    return 'invalid_code';
  }
  await query(`UPDATE email_codes SET consumed_at = now() WHERE id = $1`, [record.id]);
  return 'ok';
}

// -------------------------------------------------------------------
// POST /api/auth/register
// Создаёт неподтверждённый аккаунт и шлёт код. Токен НЕ выдаётся.
// -------------------------------------------------------------------
authRouter.post('/register', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const nickname = String(req.body.nickname || '').trim();
    const locale = ['ru', 'uk', 'en'].includes(req.body.locale) ? req.body.locale : 'ru';

    if (!EMAIL_RE.test(email)) return bad(res, 'invalid_email', 'Некорректный e-mail');
    if (password.length < 8) return bad(res, 'weak_password', 'Пароль короче 8 символов');
    if (nickname.length < 3 || nickname.length > 20) {
      return bad(res, 'invalid_nickname', 'Никнейм должен быть от 3 до 20 символов');
    }

    const existing = await query(
      `SELECT id, email_verified FROM users WHERE email = $1`,
      [email]
    );

    if (existing.rows.length) {
      const user = existing.rows[0];
      // Аккаунт есть, но почта не подтверждена — просто шлём новый код,
      // а не рассказываем, что e-mail занят (меньше утечки информации).
      if (!user.email_verified) {
        await issueCode(user.id, email, locale);
        return res.json({ ok: true, pending_verification: true });
      }
      return bad(res, 'email_taken', 'Этот e-mail уже зарегистрирован', 409);
    }

    const nickTaken = await query(`SELECT 1 FROM users WHERE lower(nickname) = lower($1)`, [
      nickname,
    ]);
    if (nickTaken.rows.length) {
      return bad(res, 'nickname_taken', 'Такой никнейм уже занят', 409);
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const { rows } = await query(
      `INSERT INTO users (email, password_hash, nickname, locale)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [email, passwordHash, nickname, locale]
    );

    await issueCode(rows[0].id, email, locale);
    res.status(201).json({ ok: true, pending_verification: true });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// POST /api/auth/verify — обмен кода на JWT
// -------------------------------------------------------------------
authRouter.post('/verify', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const code = String(req.body.code || '').trim();

    if (!EMAIL_RE.test(email) || !/^\d{6}$/.test(code)) {
      return bad(res, 'invalid_code', 'Неверный код');
    }

    const userRes = await query(`SELECT * FROM users WHERE email = $1`, [email]);
    if (!userRes.rows.length) return bad(res, 'invalid_code', 'Неверный код');
    const user = userRes.rows[0];

    const codeRes = await query(
      `SELECT * FROM email_codes
        WHERE user_id = $1 AND purpose = 'verify' AND consumed_at IS NULL
        ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );
    if (!codeRes.rows.length) return bad(res, 'code_expired', 'Код не найден');
    const record = codeRes.rows[0];

    if (new Date(record.expires_at) < new Date()) {
      return bad(res, 'code_expired', 'Код просрочен');
    }
    if (record.attempts >= MAX_CODE_ATTEMPTS) {
      return bad(res, 'code_expired', 'Слишком много попыток, запросите новый код');
    }
    if (sha256(code) !== record.code_hash) {
      await query(`UPDATE email_codes SET attempts = attempts + 1 WHERE id = $1`, [
        record.id,
      ]);
      return bad(res, 'invalid_code', 'Неверный код');
    }

    await withTransaction(async (client) => {
      await client.query(`UPDATE email_codes SET consumed_at = now() WHERE id = $1`, [
        record.id,
      ]);
      await client.query(
        `UPDATE users SET email_verified = TRUE, last_login_at = now() WHERE id = $1`,
        [user.id]
      );
    });

    const fresh = await query(`SELECT * FROM users WHERE id = $1`, [user.id]);
    res.json({ token: signToken(user.id), user: publicUser(fresh.rows[0]) });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// POST /api/auth/resend — повторная отправка кода (не чаще раза в минуту)
// -------------------------------------------------------------------
authRouter.post('/resend', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const locale = ['ru', 'uk', 'en'].includes(req.body.locale) ? req.body.locale : 'ru';

    const userRes = await query(
      `SELECT id, email_verified FROM users WHERE email = $1`,
      [email]
    );
    // Не раскрываем, есть ли такой аккаунт.
    if (!userRes.rows.length || userRes.rows[0].email_verified) {
      return res.json({ ok: true });
    }
    const user = userRes.rows[0];

    const last = await query(
      `SELECT created_at FROM email_codes
        WHERE user_id = $1 AND purpose = 'verify'
        ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );
    if (last.rows.length) {
      const elapsed = (Date.now() - new Date(last.rows[0].created_at)) / 1000;
      if (elapsed < RESEND_COOLDOWN_SECONDS) {
        return bad(
          res,
          'resend_cooldown',
          `Подождите ${Math.ceil(RESEND_COOLDOWN_SECONDS - elapsed)} с`,
          429
        );
      }
    }

    await issueCode(user.id, email, locale);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// POST /api/auth/login
// -------------------------------------------------------------------
authRouter.post('/login', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');

    const { rows } = await query(`SELECT * FROM users WHERE email = $1`, [email]);
    // Одинаковый ответ и при отсутствии пользователя, и при неверном
    // пароле — чтобы нельзя было перебором собрать список e-mail.
    if (!rows.length) {
      return bad(res, 'invalid_credentials', 'Неверный e-mail или пароль', 401);
    }
    const user = rows[0];

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return bad(res, 'invalid_credentials', 'Неверный e-mail или пароль', 401);
    }
    if (user.is_banned) {
      return bad(res, 'banned', 'Аккаунт заблокирован', 403);
    }

    if (!user.email_verified) {
      // Пароль верный, но почта не подтверждена: сразу шлём новый код.
      await issueCode(user.id, user.email, user.locale).catch(() => {});
      return bad(res, 'email_not_verified', 'Подтвердите почту', 403);
    }

    // Второй фактор: пароль верный — шлём код и ждём его на /tfa/verify.
    if (user.tfa_enabled) {
      await issueCode(user.id, user.email, user.locale, 'tfa').catch(() => {});
      return res.status(202).json({ tfa_required: true, email: user.email });
    }

    await query(`UPDATE users SET last_login_at = now() WHERE id = $1`, [user.id]);
    res.json({ token: signToken(user.id), user: publicUser(user) });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// 2FA: вход по коду из письма (второй шаг после пароля)
// POST /api/auth/tfa/verify { email, code }
// -------------------------------------------------------------------
authRouter.post('/tfa/verify', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const code = String(req.body.code || '').trim();
    if (!EMAIL_RE.test(email) || !/^\d{6}$/.test(code)) {
      return bad(res, 'invalid_code', 'Неверный код');
    }
    const { rows } = await query(`SELECT * FROM users WHERE email = $1`, [email]);
    if (!rows.length) return bad(res, 'invalid_code', 'Неверный код');
    const verdict = await checkCode(rows[0].id, code, 'tfa');
    if (verdict !== 'ok') return bad(res, verdict, 'Неверный или просроченный код');

    await query(`UPDATE users SET last_login_at = now() WHERE id = $1`, [rows[0].id]);
    const fresh = await query(`SELECT * FROM users WHERE id = $1`, [rows[0].id]);
    res.json({ token: signToken(rows[0].id), user: publicUser(fresh.rows[0]) });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// 2FA: включение (по коду из письма) и выключение
// -------------------------------------------------------------------
authRouter.post('/tfa/enable', requireAuth, async (req, res, next) => {
  try {
    await issueCode(req.user.id, req.user.email, req.user.locale, 'tfa');
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

authRouter.post('/tfa/confirm', requireAuth, async (req, res, next) => {
  try {
    const code = String(req.body.code || '').trim();
    const verdict = await checkCode(req.user.id, code, 'tfa');
    if (verdict !== 'ok') return bad(res, verdict, 'Неверный или просроченный код');
    await query(`UPDATE users SET tfa_enabled = TRUE WHERE id = $1`, [req.user.id]);
    res.json({ ok: true, tfa_enabled: true });
  } catch (err) {
    next(err);
  }
});

authRouter.post('/tfa/disable', requireAuth, async (req, res, next) => {
  try {
    await query(`UPDATE users SET tfa_enabled = FALSE WHERE id = $1`, [req.user.id]);
    res.json({ ok: true, tfa_enabled: false });
  } catch (err) {
    next(err);
  }
});

// -------------------------------------------------------------------
// Telegram-привязка: клиент берёт код, игрок отправляет его боту
// POST /api/auth/telegram/code → { code, expires_in }
// POST /api/auth/telegram/unlink — отвязать
// -------------------------------------------------------------------
authRouter.post('/telegram/code', requireAuth, async (req, res, next) => {
  try {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    await query(
      `INSERT INTO tg_codes (code, user_id, expires_at)
       VALUES ($1, $2, now() + interval '15 minutes')
       ON CONFLICT (code) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at`,
      [code, req.user.id]
    );
    res.json({ ok: true, code, expires_in: 900 });
  } catch (err) {
    next(err);
  }
});

authRouter.post('/telegram/unlink', requireAuth, async (req, res, next) => {
  try {
    await query(
      `UPDATE users SET telegram_id = NULL, telegram_username = NULL WHERE id = $1`,
      [req.user.id]
    );
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

