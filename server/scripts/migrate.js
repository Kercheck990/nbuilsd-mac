// Применяет схему (и, с флагом --seed, наполняет каталог).
// Запуск: npm run migrate   |   npm run seed
import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db.js';

const here = dirname(fileURLToPath(import.meta.url));

async function run(file) {
  const sql = readFileSync(join(here, '..', 'db', file), 'utf8');
  await pool.query(sql);
  console.log(`✓ применено: ${file}`);
}

try {
  await run('schema.sql');
  await run('migrate_002.sql');
  await run('migrate_003_cases.sql');
  await run('migrate_004_inventory_star.sql');
  if (process.argv.includes('--seed')) {
    await run('seed.sql');
    await run('seed_cases.sql');
  } else {
    try { await run('seed_cases.sql'); } catch {}
  }
  console.log('Готово.');
} catch (err) {
  console.error('Ошибка миграции:', err.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
