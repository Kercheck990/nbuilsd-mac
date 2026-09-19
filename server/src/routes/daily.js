import express from 'express';
import { query, withTransaction, applyBalance } from '../db.js';
import { requireAuth, requireAdmin } from '../middleware/auth.js';

export const dailyRouter = express.Router();
dailyRouter.use(requireAuth);

// GET /api/daily — список заданий + прогресс сегодня
dailyRouter.get('/', async (req, res, next) => {
  try {
    const { rows: tasks } = await query(`SELECT id, title, description, reward_coins, reward_item_id, requirement_type, requirement_count FROM daily_tasks WHERE is_active ORDER BY sort_order`);
    // ensure progress rows exist for today
    for (const t of tasks) {
      await query(
        `INSERT INTO user_daily_progress (user_id, task_id, date, progress) VALUES ($1,$2,CURRENT_DATE,0)
         ON CONFLICT (user_id, task_id, date) DO NOTHING`,
        [req.user.id, t.id]
      );
    }
    const { rows: prog } = await query(`SELECT task_id, progress, completed, claimed FROM user_daily_progress WHERE user_id=$1 AND date=CURRENT_DATE`, [req.user.id]);
    const map = Object.fromEntries(prog.map((r) => [r.task_id, r]));
    res.json({
      tasks: tasks.map((t) => ({
        ...t,
        progress: map[t.id]?.progress ?? 0,
        completed: !!map[t.id]?.completed,
        claimed: !!map[t.id]?.claimed,
      })),
    });
  } catch (err) { next(err); }
});

// POST /api/daily/:id/claim — забрать награду
dailyRouter.post('/:id/claim', async (req, res, next) => {
  try {
    const taskId = String(req.params.id);
    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT udp.completed, udp.claimed, dt.reward_coins, dt.reward_item_id
           FROM user_daily_progress udp JOIN daily_tasks dt ON dt.id=udp.task_id
          WHERE udp.user_id=$1 AND udp.task_id=$2 AND udp.date=CURRENT_DATE
          FOR UPDATE`,
        [req.user.id, taskId]
      );
      if (!rows.length) return { error: 'not_found' };
      const r = rows[0];
      if (!r.completed) return { error: 'not_completed' };
      if (r.claimed) return { error: 'already_claimed' };
      await client.query(`UPDATE user_daily_progress SET claimed=TRUE WHERE user_id=$1 AND task_id=$2 AND date=CURRENT_DATE`, [req.user.id, taskId]);
      let balance = null;
      if (r.reward_coins > 0) {
        balance = await applyBalance(client, req.user.id, r.reward_coins, 'daily_reward', taskId);
      }
      let inventoryId = null;
      if (r.reward_item_id) {
        const ins = await client.query(`INSERT INTO inventory (user_id, item_id, status) VALUES ($1,$2,'open') RETURNING id`, [req.user.id, r.reward_item_id]);
        inventoryId = ins.rows[0].id;
      }
      try {
        await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'daily','Ежедневное задание выполнено','Вы получили награду за задание ${taskId}')`, [req.user.id]);
      } catch (_) {}
      return { ok: true, balance_coins: balance, inventory_id: inventoryId };
    });
    if (result.error) return res.status(400).json({ error: result.error });
    res.json(result);
  } catch (err) { next(err); }
});

// helper to increment progress (called from upgrade/cases/trades)
export async function incDailyProgress(userId, type, amount = 1) {
  try {
    await query(
      `UPDATE user_daily_progress
          SET progress = LEAST(progress + $3, (SELECT requirement_count FROM daily_tasks WHERE id=user_daily_progress.task_id)),
              completed = (progress + $3) >= (SELECT requirement_count FROM daily_tasks WHERE id=user_daily_progress.task_id)
        WHERE user_id=$1 AND date=CURRENT_DATE
          AND task_id IN (SELECT id FROM daily_tasks WHERE requirement_type=$2 AND is_active)`,
      [userId, type, amount]
    );
  } catch (_) {}
}

// Admin CRUD for daily tasks
export const dailyAdminRouter = express.Router();
dailyAdminRouter.get('/admin/daily', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const { rows } = await query(`SELECT * FROM daily_tasks ORDER BY sort_order`);
    res.json({ tasks: rows });
  } catch (err) { next(err); }
});
dailyAdminRouter.post('/admin/daily', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const { id, title, description, reward_coins, reward_item_id, requirement_type, requirement_count } = req.body;
    await query(
      `INSERT INTO daily_tasks (id, title, description, reward_coins, reward_item_id, requirement_type, requirement_count)
       VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, reward_coins=EXCLUDED.reward_coins, reward_item_id=EXCLUDED.reward_item_id, requirement_type=EXCLUDED.requirement_type, requirement_count=EXCLUDED.requirement_count`,
      [String(id), String(title), String(description||''), parseInt(reward_coins)||0, reward_item_id||null, String(requirement_type||'login'), parseInt(requirement_count)||1]
    );
    res.json({ ok: true });
  } catch (err) { next(err); }
});
