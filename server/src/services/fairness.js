import crypto from 'node:crypto';

/// Provably-fair: сервер заранее фиксирует секретный сид, показывает
/// игроку только его SHA-256, а после раунда раскрывает сам сид. Игрок
/// может пересчитать ролл сам и убедиться, что результат не подкручен.

export function generateServerSeed() {
  return crypto.randomBytes(32).toString('hex');
}

export function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

/// Ролл в диапазоне [0, 100) из sha256(serverSeed:clientSeed:nonce).
/// Берём первые 13 hex-символов (52 бита) — с запасом по энтропии.
export function rollFromSeeds(serverSeed, clientSeed, nonce) {
  const hash = sha256(`${serverSeed}:${clientSeed}:${nonce}`);
  const slice = hash.slice(0, 13);
  const value = parseInt(slice, 16);
  const max = parseInt('f'.repeat(13), 16);
  return (value / max) * 100;
}

/// Шанс = (стоимость ставки / цена цели) × 100, зажатый в [min, max].
/// Потолок 75% применяется здесь, на сервере, а не только в UI.
export function computeChance(stakeValue, targetPrice, min, max) {
  if (targetPrice <= 0) return min;
  const raw = (stakeValue / targetPrice) * 100;
  return Math.min(Math.max(raw, min), max);
}

/// Тот же расчёт, но без ограничения сверху — нужен, чтобы отличить
/// «шанс упёрся в потолок» от «игрок поставил слишком много».
export function rawChance(stakeValue, targetPrice) {
  if (targetPrice <= 0) return 0;
  return (stakeValue / targetPrice) * 100;
}

export function generateEmailCode() {
  // 6 цифр, криптостойко, с ведущими нулями.
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
}
