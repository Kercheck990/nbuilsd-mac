import { query } from '../db.js';

/// Игровые ивенты: x2/x4 удача и Сейвы (благословение — ставка не сгорает).
///
/// Авторежим: каждую субботу и воскресенье, в первые 15 минут каждого часа
/// (00:00–00:15, 01:00–01:15, …) автоматически активны x2 и Сейвы.
/// Админ может форсировать: 'on' — всегда, 'off' — никогда, 'auto' — по расписанию.
/// x4 — только вручную ('on'), по расписанию не включается.
export const EVENT_KEYS = ['x2', 'x4', 'saves'];

async function setting(key) {
  const { rows } = await query(`SELECT value FROM app_settings WHERE key = $1`, [
    `event_${key}`,
  ]);
  return rows.length ? rows[0].value : 'auto';
}

/// Активна ли сейчас 15-минутка выходного дня (первые 15 минут часа, Сб/Вс, UTC).
export function isWeekendWindow(now = new Date()) {
  const day = now.getUTCDay(); // 0 = Вс, 6 = Сб
  if (day !== 0 && day !== 6) return false;
  return now.getUTCMinutes() < 15;
}

/// Конец текущей 15-минутки (для обратного отсчёта на клиенте).
export function weekendWindowEndsAt(now = new Date()) {
  const end = new Date(now);
  end.setUTCMinutes(15, 0, 0);
  return end.toISOString();
}

/// Следующее окно (для подписи «следующий запуск»).
export function nextWeekendWindow(now = new Date()) {
  const d = new Date(now);
  // Ищем ближайшую субботу/воскресенье 00 минут часа.
  for (let i = 0; i < 8 * 24 + 1; i++) {
    const cand = new Date(d.getTime() + i * 3600_000);
    cand.setUTCMinutes(0, 0, 0);
    const day = cand.getUTCDay();
    if ((day === 0 || day === 6) && cand > now) return cand.toISOString();
  }
  return null;
}

export async function activeEvents(now = new Date()) {
  const [x2mode, x4mode, savesMode] = await Promise.all([
    setting('x2'),
    setting('x4'),
    setting('saves'),
  ]);
  const weekend = isWeekendWindow(now);

  const active = {
    x2: x2mode === 'on' || (x2mode !== 'off' && weekend),
    x4: x4mode === 'on',
    saves: savesMode === 'on' || (savesMode !== 'off' && weekend),
  };
  return {
    events: EVENT_KEYS.map((key) => ({
      key,
      active: active[key],
      // обратный отсчёт имеет смысл только для авто-окна
      ends_at: active[key] && weekend ? weekendWindowEndsAt(now) : null,
      mode: key === 'x2' ? x2mode : key === 'x4' ? x4mode : savesMode,
    })),
    weekend,
    next_window_at: weekend ? null : nextWeekendWindow(now),
    server_time: now.toISOString(),
  };
}

/// Множитель удачи для апгрейда: x4 > x2 > 1.
export function luckMultiplier(eventsState) {
  const on = (k) => eventsState.events.find((e) => e.key === k)?.active;
  if (on('x4')) return 4;
  if (on('x2')) return 2;
  return 1;
}

export function savesActive(eventsState) {
  return !!eventsState.events.find((e) => e.key === 'saves')?.active;
}
