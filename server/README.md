# NFT-Grader — сервер

Node.js 20+ / Express / PostgreSQL. Отвечает за аккаунты, коды на почту,
инвентарь, топы, платежи и **расчёт раундов апгрейда** (клиент исход не решает).

## Быстрый старт с Supabase

1. Создайте проект на [supabase.com](https://supabase.com) (бесплатного
   тарифа достаточно для старта).
2. **Settings → Database → Connection string.** Supabase даёт три варианта
   подключения — берите **Session pooler** (порт `5432`). Этот сервер держит
   долгоживущий пул из 10 соединений (`src/db.js`), поэтому:
   - ✅ **Session pooler** (`5432`) — подходит, ведёт себя как обычный Postgres;
   - ✅ **прямое подключение** (`db.<project-ref>.supabase.co:5432`) — тоже
     подходит, но доступно не на всех тарифах и не работает из IPv4-only сетей
     без IPv4 add-on;
   - ⚠️ **Transaction pooler** (порт `6543`) — рассчитан на serverless/edge,
     не держит сессионное состояние между запросами так, как ожидает
     постоянный пул соединений; для этого Express-сервера не нужен.
3. Скопируйте строку вида
   `postgres://postgres.<project-ref>:<пароль>@aws-0-<регион>.pooler.supabase.com:5432/postgres`
   в `DATABASE_URL`, поставьте `DATABASE_SSL=true` (Supabase всегда требует SSL).
4. Пароль от БД — тот, что вы задали при создании проекта (не ключ `anon`/`service_role`
   из раздела API — это разные вещи: пароль нужен для прямого подключения к
   Postgres, ключи API — для клиентских Supabase-SDK, которые этот сервер не
   использует).

```bash
cd server
cp .env.example .env        # заполните DATABASE_URL из Supabase, JWT_SECRET, SMTP
npm install
npm run seed                # создаст таблицы (schema.sql) и зальёт каталог подарков
npm run dev                 # http://localhost:8080/health
```

`npm run migrate` (без `--seed`) просто применяет `db/schema.sql` — полезно
для повторного прогона на уже существующей базе, `CREATE TABLE IF NOT EXISTS`
ничего не сломает.

### Локально без Supabase

Если хотите поднять Postgres у себя для разработки:

```bash
docker run -d --name nft-pg -p 5432:5432 \
  -e POSTGRES_USER=nft -e POSTGRES_PASSWORD=nft -e POSTGRES_DB=nft_grader \
  postgres:16
```

Тогда `DATABASE_URL=postgres://nft:nft@localhost:5432/nft_grader`, `DATABASE_SSL=false`.

## Куда деплоить сам сервер

Supabase хостит только базу данных, не Node-процесс. Сервер (`server/`)
по-прежнему нужно развернуть отдельно — подойдёт **Railway**, **Render**,
**Fly.io** или свой VPS. Достаточно указать те же переменные окружения
(`DATABASE_URL` от Supabase, `JWT_SECRET`, SMTP, ключи платежей) в панели
выбранного хостинга.

## Проверка подключения к Supabase

```bash
psql "$DATABASE_URL" -c "select now();"
```

Если ошибка `ENOTFOUND`/`ETIMEDOUT` — проверьте, что регион в строке
подключения совпадает с тем, что показывает Supabase (его можно скопировать
заново на всякий случай), а `no pg_hba.conf entry` обычно означает, что
забыли `DATABASE_SSL=true`.

## Подключение клиента

Flutter обращается по адресу из `AppConstants.apiBaseUrl`:

```bash
flutter run --dart-define=API_BASE_URL=https://ваш-сервер.railway.app
```

Значения по умолчанию для разработки:
- Android-эмулятор: `http://10.0.2.2:8080`
- iOS-симулятор / Windows / macOS: `http://localhost:8080`

## Почта

Подойдёт любой SMTP. Примеры:

- **Gmail** — включите двухфакторную аутентификацию и создайте
  «пароль приложения», хост `smtp.gmail.com`, порт `465`, `SMTP_SECURE=true`.
- **Resend / Postmark / Mailgun** — надёжнее для рассылок, не попадают в спам.

Если SMTP не настроен и `MAIL_DEV_LOG=true`, код печатается в консоль сервера —
удобно тестировать регистрацию без почты.

Код: 6 цифр, живёт 10 минут, хранится только его SHA-256, максимум 5 попыток
ввода, повторная отправка раз в 60 секунд.

## Платежи

Монеты начисляются **только** в обработчике вебхука, после проверки подписи.
Клиент баланс не трогает. Повторный вебхук ничего не задвоит: строка платежа
блокируется `FOR UPDATE`, начисление отмечается флагом `credited`.

### Stripe (карты)
1. `STRIPE_SECRET_KEY` из https://dashboard.stripe.com/apikeys
2. Webhooks → добавить endpoint `{PUBLIC_URL}/api/payments/webhook/stripe`,
   событие `checkout.session.completed`
3. Секрет подписи → `STRIPE_WEBHOOK_SECRET`

Локально: `stripe listen --forward-to localhost:8080/api/payments/webhook/stripe`

### Crypto Pay (USDT / TON, через @CryptoBot)
1. В Telegram: @CryptoBot → Crypto Pay → Create App → токен в `CRYPTO_PAY_TOKEN`
2. В настройках приложения укажите вебхук `{PUBLIC_URL}/api/payments/webhook/crypto`

### Telegram Stars
Требуется бот. Ссылка на оплату создаётся через `createInvoiceLink` (валюта `XTR`),
а апдейт `successful_payment` ваш бот пересылает на
`{PUBLIC_URL}/api/payments/webhook/stars`.

Курс задаётся `COINS_PER_UNIT` (по умолчанию 100 монет = 1 USD).

## Потолок 75%

`config.game.maxChancePercent = 75` — то же число, что в
`lib/core/constants/app_constants.dart`. Проверка дублируется в
`routes/upgrade.js`: раунд с шансом выше потолка отклоняется с ошибкой
`chance_above_limit`, даже если запрос пришёл в обход приложения.
Меняя значение, правьте оба места.

## API

| Метод | Путь | Описание |
|---|---|---|
| POST | `/api/auth/register` | создать аккаунт, выслать код |
| POST | `/api/auth/verify` | обменять код на JWT |
| POST | `/api/auth/resend` | выслать код повторно |
| POST | `/api/auth/login` | вход |
| GET | `/api/me` | текущий пользователь |
| GET | `/api/items` | каталог подарков |
| GET | `/api/inventory` | инвентарь игрока |
| POST | `/api/inventory/:id/sell` | продать предмет |
| POST | `/api/upgrade` | провести раунд |
| GET | `/api/history` | последние 50 раундов |
| GET | `/api/leaderboard` | топы (`metric`, `period`) |
| POST | `/api/payments/create` | создать счёт |
| GET | `/api/payments/:id` | статус платежа |
| POST | `/api/payments/webhook/*` | вебхуки провайдеров |
| GET | `/api/config` | публичные правила (в т.ч. потолок) |

## Provably fair

Перед броском сервер генерирует `server_seed`, публикует `sha256(server_seed)`,
а после раунда раскрывает сам сид. Игрок пересчитывает результат сам:

```
roll = (первые 13 hex-символов sha256("serverSeed:clientSeed:nonce") / f×13) × 100
победа, если roll < chance
```

Все поля хранятся в таблице `rounds` и отдаются в `/api/history`.

## Перед запуском с реальными деньгами

Механика «поставил ценность → можешь её потерять» с пополнением реальными
средствами в большинстве юрисдикций (включая Украину) регулируется как азартная
игра: нужна лицензия, верификация возраста и личности, ограничения по рекламе.
App Store и Google Play такие приложения ревьюят отдельно. Галочка 18+ при
регистрации — минимум, а не комплаенс. Поговорите с юристом по игорному праву
до подключения боевых ключей платёжных провайдеров.
