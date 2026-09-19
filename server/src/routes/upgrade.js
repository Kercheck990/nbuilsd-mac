import express from 'express';
import rateLimit from 'express-rate-limit';

import { config } from '../config.js';
import { applyNcBalance, withTransaction } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import {
  activeEvents,
  luckMultiplier,
  savesActive,
} from '../services/events.js';
import {
  computeChance,
  generateServerSeed,
  rawChance,
  rollFromSeeds,
  sha256,
} from '../services/fairness.js';
import { incDailyProgress } from './daily.js';

export const upgradeRouter = express.Router();

upgradeRouter.use(requireAuth);
upgradeRouter.use(
  rateLimit({ windowMs: 60_000, limit: 60, legacyHeaders: false })
);

/// POST /api/upgrade
///
/// Весь раунд считается здесь, на сервере: клиент присылает только то,
/// ЧТО он ставит и ВО ЧТО апгрейдит. Шанс, ролл и исход определяет сервер
/// и записывает в таблицу rounds. Клиент получает готовый результат и
/// лишь проигрывает анимацию — подменить исход из приложения невозможно.
///
/// Здесь же стоит жёсткая проверка потолка: если стоимость ставки даёт
/// больше config.game.maxChancePercent (75%), раунд отклоняется.
upgradeRouter.post('/', async (req, res, next) => {
  try {
    const stakeIds = Array.isArray(req.body.stake_inventory_ids)
      ? req.body.stake_inventory_ids.map(String)
      : [];
    const stakeCoins = Math.max(0, Math.floor(Number(req.body.stake_coins) || 0));
    const targetItemId = String(req.body.target_item_id || '');

    if (!targetItemId) {
      return res.status(400).json({ error: 'no_target', message: 'Не выбрана цель' });
    }
    if (!stakeIds.length && stakeCoins <= 0) {
      return res.status(400).json({ error: 'no_stake', message: 'Пустая ставка' });
    }

    const result = await withTransaction(async (client) => {
      // --- 1. Блокируем пользователя и ставку (ставка в NC) ------------------------
      const userRes = await client.query(
        `SELECT id, balance_nc, client_seed, boost_saves_until, boost_x2_until, boost_x4_until FROM users WHERE id = $1 FOR UPDATE`,
        [req.user.id]
      );
      const user = userRes.rows[0];

      if (stakeCoins > user.balance_nc) {
        return { error: 'insufficient_funds', message: 'Недостаточно NC' };
      }

      let stakeItems = [];
      if (stakeIds.length) {
        const invRes = await client.query(
          `SELECT inv.id, it.price_coins
             FROM inventory inv
             JOIN items it ON it.id = inv.item_id
            WHERE inv.id = ANY($1::uuid[])
              AND inv.user_id = $2
              AND inv.status = 'open'
            FOR UPDATE OF inv`,
          [stakeIds, user.id]
        );
        // Если хоть один предмет не принадлежит игроку или уже занят —
        // раунд не начинаем.
        if (invRes.rows.length !== stakeIds.length) {
          return { error: 'invalid_stake', message: 'Часть предметов недоступна' };
        }
        stakeItems = invRes.rows;
      }

      const targetRes = await client.query(
        `SELECT id, price_coins, name FROM items WHERE id = $1 AND is_active = TRUE`,
        [targetItemId]
      );
      if (!targetRes.rows.length) {
        return { error: 'invalid_target', message: 'Цель не найдена' };
      }
      const target = targetRes.rows[0];

      // --- 2. Считаем шанс и проверяем потолок -----------------------
      const stakeValue =
        stakeItems.reduce((sum, i) => sum + i.price_coins, 0) + stakeCoins;

      const raw = rawChance(stakeValue, target.price_coins);
      if (raw > config.game.maxChancePercent + 1e-6) {
        return {
          error: 'chance_above_limit',
          message: `Шанс ${raw.toFixed(1)}% превышает потолок ${config.game.maxChancePercent}%`,
          max_chance_percent: config.game.maxChancePercent,
        };
      }

      // Ивенты: x2/x4 умножают шанс (потолок 75% нерушим), Сейвы возвращают
      // ставку при проигрыше (глобальные + персональные из Shop NPC).
      const eventsState = await activeEvents();
      // персональные бусты пользователя (из shop за NPC)
      const userBoostSaves = user.boost_saves_until && new Date(user.boost_saves_until) > new Date();
      const userBoostX2 = user.boost_x2_until && new Date(user.boost_x2_until) > new Date();
      const userBoostX4 = user.boost_x4_until && new Date(user.boost_x4_until) > new Date();
      // интегрируем в состояние
      if (userBoostX4) eventsState.events.find((e) => e.key === 'x4').active = true;
      else if (userBoostX2) eventsState.events.find((e) => e.key === 'x2').active = true;
      if (userBoostSaves) eventsState.events.find((e) => e.key === 'saves').active = true;
      const mult = luckMultiplier(eventsState);
      const saves = savesActive(eventsState);

      const chance = Math.min(
        computeChance(
          stakeValue,
          target.price_coins,
          config.game.minChancePercent,
          config.game.maxChancePercent
        ) * mult,
        config.game.maxChancePercent
      );

      // --- 3. Provably-fair бросок -----------------------------------
      const serverSeed = generateServerSeed();
      const serverSeedHash = sha256(serverSeed);
      const nonce = Date.now();
      const roll = rollFromSeeds(serverSeed, user.client_seed, nonce);
      const success = roll <= chance + 1e-9; // включительно: попал в зелёный — выиграл

      // --- 4. Списываем ставку в NC (Сейвы: 55% шанс спасти при проигрыше — 50-60% как просили, не каждый раз) --
      const saved = saves && !success && Math.random() < 0.55;
      if (!saved) {
        if (stakeItems.length) {
          await client.query(
            `UPDATE inventory SET status = 'consumed' WHERE id = ANY($1::uuid[])`,
            [stakeItems.map((i) => i.id)]
          );
        }
      }
      let balance = user.balance_nc;
      if (stakeCoins > 0 && !saved) {
        balance = await applyNcBalance(client, user.id, -stakeCoins, 'upgrade_stake');
      }

      // --- 5. Выдаём приз при победе ---------------------------------
      let wonInventoryId = null;
      if (success) {
        const ins = await client.query(
          `INSERT INTO inventory (user_id, item_id, status)
           VALUES ($1, $2, 'open') RETURNING id`,
          [user.id, target.id]
        );
        wonInventoryId = ins.rows[0].id;
      }

      const profit = success ? target.price_coins - stakeValue : saved ? 0 : -stakeValue;

      const roundRes = await client.query(
        `INSERT INTO rounds (user_id, target_item_id, stake_value, stake_coins,
                             chance_percent, roll_percent, success, profit_coins,
                             server_seed, server_seed_hash, client_seed, nonce)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         RETURNING id, created_at`,
        [
          user.id,
          target.id,
          stakeValue,
          stakeCoins,
          chance.toFixed(3),
          roll.toFixed(3),
          success,
          profit,
          serverSeed,
          serverSeedHash,
          user.client_seed,
          nonce,
        ]
      );

      return {
        round_id: roundRes.rows[0].id,
        success,
        saved,
        luck_multiplier: mult,
        chance_percent: Number(chance.toFixed(3)),
        roll_percent: Number(roll.toFixed(3)),
        stake_value: stakeValue,
        profit_coins: profit,
        balance_nc: balance,
        balance_coins: null,
        won_inventory_id: wonInventoryId,
        target: { id: target.id, name: target.name, price_coins: target.price_coins },
        fairness: {
          server_seed: serverSeed,
          server_seed_hash: serverSeedHash,
          client_seed: user.client_seed,
          nonce,
        },
      };
    });

    if (result.error) {
      return res.status(400).json(result);
    }
    // daily progress: upgrade count
    try { await incDailyProgress(req.user.id, 'upgrade', 1); } catch (_) {}
    res.json(result);
  } catch (err) {
    next(err);
  }
});
