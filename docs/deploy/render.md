# Backend on Render

The Laravel API (`backend/`) as a Render Docker web service, defined in [render.yaml](../../render.yaml).

| Piece | File |
|---|---|
| Image: PHP 8.2 + Apache, `pdo_mysql`, `bcmath`, `intl`, `opcache`; production Composer install; Vite assets for `/` | [backend/Dockerfile](../../backend/Dockerfile) |
| Start-up: listen on `$PORT`, `APP_URL` from `RENDER_EXTERNAL_URL`, refuse to start without `APP_KEY`, config/view cache. **No migrations.** | [backend/docker/entrypoint.sh](../../backend/docker/entrypoint.sh) |
| Apache vhost (document root `public/`, `.htaccess` routing), PHP production settings | [backend/docker/](../../backend/docker/) |
| HTTPS URLs behind Render's proxy (trusted `X-Forwarded-Proto/Host/Port`; `X-Forwarded-For` deliberately not trusted) | [backend/bootstrap/app.php](../../backend/bootstrap/app.php) |

Health check: `/up` (Laravel boots). It does **not** touch the database; see the verification below.

## Database requirement

The service needs the existing MySQL database, reachable **over the internet** from Render:

- A Railway `*.railway.internal` host only works inside Railway's private network. Render cannot reach it.
- Railway MySQL can be reached from outside only through its TCP proxy (Railway dashboard → MySQL → Settings →
  Networking → TCP Proxy), which gives a public host and port. That requires the MySQL service to be running.
- Never point the service at a new empty database, and never switch engines (e.g. to PostgreSQL) without a
  planned, backed-up data migration.

## Environment variables (Render dashboard → service → Environment)

Set by the Blueprint: `APP_ENV=production`, `APP_DEBUG=false`, `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`,
`DB_CONNECTION=mysql`, `SESSION_DRIVER=database`, `CACHE_STORE=database`, `QUEUE_CONNECTION=database`.

Entered in the dashboard (secret, `sync: false`):

| Variable | Value |
|---|---|
| `APP_KEY` | the **existing** key of this application (copied from the previous host), never a new one |
| `DB_HOST`, `DB_PORT` | the database's public host and port |
| `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | the existing database credentials |
| `APP_URL` | optional; defaults to the Render URL |

## Create the service

1. Render Dashboard → **New → Blueprint** → repository `abdelmoen1/micro-erp-system`, branch `main`
   (after this branch is merged) → Render reads `render.yaml` and asks for the `sync: false` values.
2. First deploy: watch the build and runtime logs.

Migrations do not run automatically. If `php artisan migrate:status` (Render shell) shows pending migrations,
review them before running anything against production data.

## Verify before switching the app

Replace `<url>` with the URL Render assigns (`https://<name>.onrender.com`):

| Check | Expected |
|---|---|
| `GET <url>/up` | 200 (Laravel boots; says nothing about the database) |
| `GET <url>/api/v1/me` with `Accept: application/json` | 401 `UNAUTHENTICATED` JSON |
| `POST <url>/api/v1/login` with `{}` | 422 `VALIDATION_FAILED` JSON |
| `POST <url>/api/v1/login` with an unknown `@example.invalid` email | 401 `INVALID_CREDENTIALS`: proves a real `users` query (only side effect: a 60 s throttle counter) |
| Login with a real account, then `GET /api/v1/me` | 200 with the user: token handling works |
| Any error response | JSON envelope with `correlation_id`, no stack trace |

Only then change `MOBILE_API_BASE_URL` (GitHub variable used by the mobile release/patch workflows) to
`<url>/api/v1`.

## Free plan limits

- The service spins down after 15 minutes without traffic; the next request waits about a minute while it starts.
  Not suitable for a shop that needs instant responses at all times (a paid instance type avoids this).
- 750 free instance hours per workspace per month; when they run out, free services stop until the next month.
- The filesystem is temporary (lost on redeploy/restart/spin-down). The API stores no files, so this is fine.
- Outbound SMTP ports are blocked on free services (mail is `log` today).
- `routes/console.php` schedules `idempotency:prune` daily. Nothing runs the scheduler on a free web service, so
  old idempotency keys (older than 30 days) are not pruned automatically. This is harmless at current volumes;
  run it by hand from the Render shell when needed, or add a Render cron job (paid).
