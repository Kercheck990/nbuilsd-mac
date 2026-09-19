import express from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

export const notificationsRouter = express.Router();
notificationsRouter.use(requireAuth);

// GET /api/notifications?limit=20
notificationsRouter.get('/', async (req, res, next) => {
  try {
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const { rows } = await query(
      `SELECT id, type, title, body, is_read, created_at FROM notifications WHERE user_id=$1 ORDER BY id DESC LIMIT $2`,
      [req.user.id, limit]
    );
    const unread = rows.filter((r) => !r.is_read).length;
    res.json({ notifications: rows, unread });
  } catch (err) { next(err); }
});

notificationsRouter.post('/:id/read', async (req, res, next) => {
  try {
    await query(`UPDATE notifications SET is_read=TRUE WHERE id=$1 AND user_id=$2`, [req.params.id, req.user.id]);
    res.json({ ok: true });
  } catch (err) { next(err); }
});
notificationsRouter.post('/read-all', async (req, res, next) => {
  try {
    await query(`UPDATE notifications SET is_read=TRUE WHERE user_id=$1 AND NOT is_read`, [req.user.id]);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

// Helper to create notification (call from other routes)
export async function notifyUser(userId, type, title, body) {
  try {
    await query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,$2,$3,$4)`, [userId, type, title, body]);
  } catch (_) {}
}
export async function notifyAll(type, title, body) {
  try {
    await query(`INSERT INTO notifications (user_id, type, title, body) SELECT id,$2,$3,$4 FROM users WHERE NOT is_banned`, [type, title, body]);
  } catch (_) {}
}
