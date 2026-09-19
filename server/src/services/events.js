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

/// Авто-ивент: Пт/Сб/Вс 15:00-15:15 UTC — blessing (saves) + x2 (как просили)
export function isWeekendWindow(now = new Date()) {
  const day = now.getUTCDay(); // 5=Пт,6=Сб,0=Вс
  if (day !== 5 && day !== 6 && day !== 0) return false;
  const h = now.getUTCHours();
  const m = now.getUTCMinutes();
  return h === 15 && m < 15;
}
export function weekendWindowEndsAt(now = new Date()) {
  const end = new Date(now);
  end.setUTCMinutes(15, 0, 0);
  end.setUTCSeconds(0);
  return end.toISOString();
}
export function nextWeekendWindow(now = new Date()) {
  const d = new Date(now);
  for (let i = 0; i < 8 * 24 * 60; i++) {
    const cand = new Date(d.getTime() + i * 60000);
    cand.setUTCMinutes(0, 0, 0);
    cand.setUTCSeconds(0, 0);
    const day = cand.getUTCDay();
    const h = cand.getUTCHours();
    if ((day === 5 || day === 6 || day === 0) && h === 15 && cand > now) return cand;
  }
  return null;
}
export function nextWeekendWindowIso(now = new Date()) {
  const n = nextWeekendWindow(now);
  return n ? n.toISOString() : null;
}

async function untilActive(key) {
  const { rows } = await query(`SELECT value FROM app_settings WHERE key = $1`, [`event_${key}_until`]);
  if (!rows.length) return null;
  const ts = new Date(rows[0].value);
  if (isNaN(ts.getTime())) return null;
  return ts > new Date() ? ts.toISOString() : null;
}

export async function activeEvents(now = new Date()) {
  const [x2mode, x4mode, savesMode, x2until, savesUntil] = await Promise.all([
    setting('x2'),
    setting('x4'),
    setting('saves'),
    untilActive('x2'),
    untilActive('saves'),
  ]);
  const weekend = isWeekendWindow(now);
  const abuse = isAdminAbuseWindow(now);
  const manualX2 = x2until != null;
  const manualSaves = savesUntil != null;

  const active = {
    x2: manualX2 || x2mode === 'on' || (x2mode !== 'off' && weekend) || abuse,
    x4: x4mode === 'on',
    saves: manualSaves || savesMode === 'on' || (savesMode !== 'off' && weekend) || abuse,
  };
  const abuseEnds = abuse ? adminAbuseEndsAt(now) : null;
  const weekendEnds = weekend ? weekendWindowEndsAt(now) : null;
  return {
    events: EVENT_KEYS.map((key) => {
      const isActive = active[key];
      let endsAt = null;
      if (isActive) {
        if (key === 'x2' && manualX2) endsAt = x2until;
        else if (key === 'saves' && manualSaves) endsAt = savesUntil;
        else if (abuse && (key === 'x2' || key === 'saves')) endsAt = abuseEnds;
        else if (weekend) endsAt = weekendEnds;
      }
      return {
        key,
        active: isActive,
        ends_at: endsAt,
        mode: key === 'x2' ? x2mode : key === 'x4' ? x4mode : savesMode,
      };
    }),
    weekend,
    admin_abuse: abuse,
    admin_abuse_ends_at: abuseEnds,
    next_admin_abuse_at: abuse ? null : nextAdminAbuse(now)?.toISOString() ?? null,
    next_window_at: weekend ? null : nextWeekendWindowIso(now),
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

// ── Admin Abuse ──
// Пятница 15:00 UTC и Суббота 15:00 UTC — по 15 минут админ абьюза (x2 + saves)
export function isAdminAbuseWindow(now = new Date()) {
  const day = now.getUTCDay(); // 5=Пт, 6=Сб
  const hour = now.getUTCHours();
  const min = now.getUTCMinutes();
  if ((day === 5 || day === 6) && hour === 15 && min < 15) return true;
  return false;
}
export function nextAdminAbuse(now = new Date()) {
  const d = new Date(now);
  for (let i = 0; i < 7 * 24 * 60; i++) {
    const cand = new Date(d.getTime() + i * 60000);
    const day = cand.getUTCDay();
    const hour = cand.getUTCHours();
    const min = cand.getUTCMinutes();
    if ((day === 5 || day === 6) && hour === 15 && min === 0 && cand > now) return cand;
  }
  return null;
}
export function adminAbuseEndsAt(now = new Date()) {
  if (!isAdminAbuseWindow(now)) return null;
  const end = new Date(now);
  end.setUTCMinutes(15, 0, 0);
  return end.toISOString();
}
