import express from 'express';

import { query, withTransaction } from '../db.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';

export const ticketsRouter = express.Router();
ticketsRouter.use(requireAuth);

function bad(res, code, message, status = 400) {
  return res.status(status).json({ error: code, message });
}

async function ticketWithLast(userId, adminView, status) {
  const { rows } = await query(
    `SELECT t.id, t.subject, t.status, t.created_at, t.updated_at,
            u.nickname AS author_nickname,
            (SELECT m.text FROM ticket_messages m
              WHERE m.ticket_id = t.id ORDER BY m.created_at DESC LIMIT 1) AS last_text,
            (SELECT m.is_admin FROM ticket_messages m
              WHERE m.ticket_id = t.id ORDER BY m.created_at DESC LIMIT 1) AS last_is_admin
       FROM tickets t
       JOIN users u ON u.id = t.user_id
      WHERE (t.user_id = $1 OR $2 = TRUE)
        AND ($3 = '' OR t.status = $3)
      ORDER BY t.updated_at DESC
      LIMIT 50`,
    [userId, adminView, status || '']
  );
  return rows;
}

/// GET /api/tickets — мои обращения.
ticketsRouter.get('/', async (req, res, next) => {
  try {
    res.json({ tickets: await ticketWithLast(req.user.id, false, '') });
  } catch (err) {
    next(err);
  }
});

/// POST /api/tickets — новое обращение.
ticketsRouter.post('/', async (req, res, next) => {
  try {
    const subject = String(req.body.subject || '').trim().slice(0, 120);
    const text = String(req.body.text || '').trim().slice(0, 2000);
    if (!subject) return bad(res, 'no_subject', 'Укажите тему');
    if (!text) return bad(res, 'no_text', 'Опишите проблему');

    const id = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `INSERT INTO tickets (user_id, subject) VALUES ($1, $2) RETURNING id`,
        [req.user.id, subject]
      );
      await client.query(
        `INSERT INTO ticket_messages (ticket_id, author_id, is_admin, text)
         VALUES ($1, $2, FALSE, $3)`,
        [rows[0].id, req.user.id, text]
      );
      return rows[0].id;
    });
    res.status(201).json({ ok: true, ticket_id: id });
  } catch (err) {
    next(err);
  }
});

/// GET /api/tickets/:id — переписка.
ticketsRouter.get('/:id', async (req, res, next) => {
  try {
    const { rows: tickets } = await query(
      `SELECT t.*, u.nickname AS author_nickname FROM tickets t
         JOIN users u ON u.id = t.user_id
        WHERE t.id = $1 AND (t.user_id = $2 OR $3 = TRUE)`,
      [req.params.id, req.user.id, req.user.is_admin]
    );
    if (!tickets.length) return bad(res, 'not_found', 'Тикет не найден', 404);
    const { rows: messages } = await query(
      `SELECT m.id, m.text, m.is_admin, m.created_at, u.nickname AS author
         FROM ticket_messages m
         LEFT JOIN users u ON u.id = m.author_id
        WHERE m.ticket_id = $1
        ORDER BY m.created_at ASC`,
      [req.params.id]
    );
    res.json({ ticket: tickets[0], messages });
  } catch (err) {
    next(err);
  }
});

/// POST /api/tickets/:id/messages — ответить.
ticketsRouter.post('/:id/messages', async (req, res, next) => {
  try {
    const text = String(req.body.text || '').trim().slice(0, 2000);
    if (!text) return bad(res, 'no_text', 'Пустое сообщение');

    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `SELECT * FROM tickets WHERE id = $1 FOR UPDATE`,
        [req.params.id]
      );
      if (!rows.length) return { error: 'not_found' };
      const ticket = rows[0];
      const mine = ticket.user_id === req.user.id;
      if (!mine && !req.user.is_admin) return { error: 'forbidden' };
      if (ticket.status === 'closed') return { error: 'closed' };

      await client.query(
        `INSERT INTO ticket_messages (ticket_id, author_id, is_admin, text)
         VALUES ($1, $2, $3, $4)`,
        [req.params.id, req.user.id, req.user.is_admin && !mine, text]
      );
      await client.query(
        `UPDATE tickets SET status = $2, updated_at = now() WHERE id = $1`,
        [req.params.id, req.user.is_admin && !mine ? 'answered' : 'open']
      );
      // уведомление
      try {
        if (req.user.is_admin && !mine) {
          await client.query(`INSERT INTO notifications (user_id, type, title, body) VALUES ($1,'ticket','Администратор ответил на тикет','Вам ответили в тикете ${ticket.subject}')`, [ticket.user_id]);
        }
      } catch (_) {}
      return { ok: true };
    });

    if (result.error === 'not_found') return bad(res, 'not_found', 'Тикет не найден', 404);
    if (result.error === 'forbidden') return bad(res, 'forbidden', 'Не ваш тикет', 403);
    if (result.error === 'closed') return bad(res, 'closed', 'Тикет закрыт');
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

/// POST /api/tickets/:id/close — закрыть.
ticketsRouter.post('/:id/close', async (req, res, next) => {
  try {
    const { rowCount } = await query(
      `UPDATE tickets SET status = 'closed', updated_at = now()
        WHERE id = $1 AND (user_id = $2 OR $3 = TRUE)`,
      [req.params.id, req.user.id, req.user.is_admin]
    );
    if (!rowCount) return bad(res, 'not_found', 'Тикет не найден', 404);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

/// GET /api/tickets/admin/all — все тикеты (админ).
ticketsRouter.get('/admin/all', requireAdmin, async (req, res, next) => {
  try {
    const status = ['open', 'answered', 'closed'].includes(req.query.status)
      ? req.query.status
      : '';
    res.json({ tickets: await ticketWithLast(req.user.id, true, status) });
  } catch (err) {
    next(err);
  }
});
