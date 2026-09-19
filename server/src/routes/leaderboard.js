import express from 'express';
import jwt from 'jsonwebtoken';

import { config } from '../config.js';
import { applyBalance, query, withTransaction } from '../db.js';

export const leaderboardRouter = express.Router();

const PERIODS = {
  day: "now() - interval '1 day'",
  week: "now() - interval '7 days'",
  all: "'epoch'::timestamptz",
};

/// Категории топа:
/// balance — монеты на балансе, inventory — стоимость инвентаря,
/// hours — наигранные часы, wins — победы, profit — профит.
const METRICS = ['balance', 'inventory', 'hours', 'wins', 'profit'];

const TOP_REWARD_COINS = 0;

/// Определяем текущего игрока, если токен есть, — чтобы подсветить его
/// строку. Отсутствие токена не ошибка: топы публичные.
function optionalUserId(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(header.slice(7), config.jwt.secret).sub;
  } catch {
    return null;
  }
}

/// Топ-3 получают только галочку «Лидер» — монеты за место в топе убраны по просьбе заказчика.
/// Выдача бейджа происходит лениво при просмотре топа.
async function grantTopRewards(metric, topRows) {
  const granted = [];
  const winners = topRows.slice(0, 3);
  for (const w of winners) {
    try {
      await withTransaction(async (client) => {
        // Только бейдж, без монет и без top_rewards
        await client.query(
          `UPDATE users SET badges = (SELECT array_agg(DISTINCT b) FROM unnest(badges || ARRAY['top']) AS b)
            WHERE id = $1 AND NOT ('top' = ANY(badges))`,
          [w.id]
        );
        try {
          await client.query(
            `INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'leader','Вы в топе!','Вы вошли в топ-3 категории ${metric} — вам выдан статус Лидер 🏆')`,
            [w.id]
          );
        } catch (_) {}
      });
    } catch {}
  }
  return granted;
}

/// GET /api/leaderboard?metric=balance|inventory|hours|wins|profit&period=day|week|all&limit=35
leaderboardRouter.get('/', async (req, res, next) => {
  try {
    const metric = METRICS.includes(req.query.metric) ? req.query.metric : 'inventory';
    const period = PERIODS[req.query.period] ? req.query.period : 'all';
    const since = PERIODS[period];
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 35));
    const meId = optionalUserId(req);

    let sql;
    if (metric === 'balance') {
      sql = `
        SELECT u.id, u.nickname, u.avatar_url, u.badges,
               u.balance_coins::bigint AS value,
               COALESCE((SELECT COUNT(*) FROM rounds r
                          WHERE r.user_id = u.id AND r.success
                            AND r.created_at >= ${since}), 0)::int AS wins
          FROM users u
         WHERE u.email_verified AND NOT u.is_banned AND COALESCE(u.hide_from_top,false)=false
         ORDER BY value DESC
         LIMIT ${limit}`;
    } else if (metric === 'inventory') {
      sql = `
        SELECT u.id, u.nickname, u.avatar_url, u.badges,
               COALESCE(SUM(it.price_coins), 0)::bigint AS value,
               COALESCE((SELECT COUNT(*) FROM rounds r
                          WHERE r.user_id = u.id AND r.success
                            AND r.created_at >= ${since}), 0)::int AS wins
          FROM users u
          LEFT JOIN inventory inv ON inv.user_id = u.id AND inv.status = 'open'
          LEFT JOIN items it ON it.id = inv.item_id
         WHERE u.email_verified AND NOT u.is_banned AND COALESCE(u.hide_from_top,false)=false
         GROUP BY u.id
        HAVING COALESCE(SUM(it.price_coins), 0) > 0
         ORDER BY value DESC
         LIMIT ${limit}`;
    } else if (metric === 'hours') {
      sql = `
        SELECT u.id, u.nickname, u.avatar_url, u.badges,
               (u.playtime_seconds / 3600)::bigint AS value,
               COALESCE((SELECT COUNT(*) FROM rounds r
                          WHERE r.user_id = u.id AND r.success
                            AND r.created_at >= ${since}), 0)::int AS wins
          FROM users u
         WHERE u.email_verified AND NOT u.is_banned AND u.playtime_seconds > 0 AND COALESCE(u.hide_from_top,false)=false
         ORDER BY u.playtime_seconds DESC
         LIMIT ${limit}`;
    } else if (metric === 'wins') {
      sql = `
        SELECT u.id, u.nickname, u.avatar_url, u.badges,
               COUNT(*) FILTER (WHERE r.success)::bigint AS value,
               COUNT(*) FILTER (WHERE r.success)::int AS wins
          FROM users u
          JOIN rounds r ON r.user_id = u.id AND r.created_at >= ${since}
         WHERE u.email_verified AND NOT u.is_banned AND COALESCE(u.hide_from_top,false)=false
         GROUP BY u.id
        HAVING COUNT(*) FILTER (WHERE r.success) > 0
         ORDER BY value DESC
         LIMIT ${limit}`;
    } else {
      sql = `
        SELECT u.id, u.nickname, u.avatar_url, u.badges,
               SUM(r.profit_coins)::bigint AS value,
               COUNT(*) FILTER (WHERE r.success)::int AS wins
          FROM users u
          JOIN rounds r ON r.user_id = u.id AND r.created_at >= ${since}
         WHERE u.email_verified AND NOT u.is_banned AND COALESCE(u.hide_from_top,false)=false
         GROUP BY u.id
         ORDER BY value DESC
         LIMIT ${limit}`;
    }

    const { rows } = await query(sql);
    const granted = await grantTopRewards(metric, rows);

    res.json({
      metric,
      period,
      top_reward_coins: TOP_REWARD_COINS,
      rows: rows.map((r, i) => ({
        rank: i + 1,
        nickname: r.nickname,
        avatar_url: r.avatar_url,
        badges: r.badges || [],
        value: Number(r.value),
        wins: Number(r.wins),
        is_me: meId != null && r.id === meId,
        reward_granted: granted.includes(r.id),
      })),
    });
  } catch (err) {
    next(err);
  }
});
