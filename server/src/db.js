import pg from 'pg';
import { config } from './config.js';

// Целые BIGINT приходят строками — приводим к числу, чтобы JSON-ответы
// содержали числа, а не "1200".
pg.types.setTypeParser(20, (v) => (v === null ? null : Number(v)));
pg.types.setTypeParser(1700, (v) => (v === null ? null : Number(v)));

export const pool = new pg.Pool({
  connectionString: config.db.url,
  ssl: config.db.ssl ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30_000,
});

pool.on('error', (err) => console.error('Ошибка пула PostgreSQL:', err.message));

export const query = (text, params) => pool.query(text, params);

/// Транзакция с автоматическим ROLLBACK при исключении.
/// Используется везде, где деньги и предметы меняются вместе.
export async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// Меняет баланс и пишет строку в ledger. Всегда внутри транзакции.
/// Возвращает новый баланс. Бросает ошибку, если денег не хватает.
export async function applyBalance(client, userId, delta, reason, refId = null) {
  const { rows } = await client.query(
    `UPDATE users
        SET balance_coins = balance_coins + $2
      WHERE id = $1
       RETURNING balance_coins, balance_nc`,
    [userId, delta]
  );
  if (!rows.length) throw new Error('user_not_found');
  const balance = rows[0].balance_coins;

  await client.query(
    `INSERT INTO ledger (user_id, delta_coins, delta_nc, reason, ref_id, balance_after, balance_after_nc)
     VALUES ($1, $2, 0, $3, $4, $5, $6)`,
    [userId, delta, reason, refId, balance, rows[0].balance_nc]
  );
  return balance;
}

/// Меняет NC баланс и пишет в ledger. Всегда внутри транзакции.
export async function applyNcBalance(client, userId, deltaNc, reason, refId = null) {
  const { rows } = await client.query(
    `UPDATE users
        SET balance_nc = balance_nc + $2
      WHERE id = $1
       RETURNING balance_nc, balance_coins`,
    [userId, deltaNc]
  );
  if (!rows.length) throw new Error('user_not_found');
  if (rows[0].balance_nc < 0) throw new Error('insufficient_nc');
  const balanceNc = rows[0].balance_nc;
  await client.query(
    `INSERT INTO ledger (user_id, delta_coins, delta_nc, reason, ref_id, balance_after, balance_after_nc)
     VALUES ($1, 0, $2, $3, $4, $5, $6)`,
    [userId, deltaNc, reason, refId, rows[0].balance_coins, balanceNc]
  );
  return balanceNc;
}
