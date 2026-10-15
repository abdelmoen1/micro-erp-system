# 12 — Release and Deployment Plan

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**
> **No environment has been provisioned and nothing has been deployed.** The hosting target is pending (D-25).

## 1. Environments

| Env | Purpose | Backend | Web | Mobile | Database | Data |
|---|---|---|---|---|---|---|
| **Local** | Development | XAMPP PHP 8.2 / `php artisan serve` | `vite dev` | Emulator or device → local API (LAN IP) | Local MySQL `hisbah_dev` | Seeded fake data |
| **Test** | Automated tests | PHPUnit | CI lint/build | `flutter test` | `:memory:` sqlite + disposable `hisbah_test` | Generated per test |
| **Staging** | UAT, performance, restore drill | Same stack as production | Built SPA | Internal-track APK → staging URL | `hisbah_staging` | Seeded or anonymised only |
| **Production** | Real shops | PHP 8.2+, queue worker, scheduler | Built SPA behind HTTPS | Released APK → production URL | `hisbah_prod` + daily backups | Real |

### 1.1 Hosting requirements (any option under D-25)

- PHP ≥ 8.2 with `bcmath`, `pdo_mysql`, `mbstring`, `openssl`.
- MySQL 8.
- SSH or deploy hooks.
- A process supervisor for `queue:work`.
- Cron for `schedule:run`.
- HTTPS (Let's Encrypt or managed).
- Automated daily DB backups with ≥ 14 days retention, stored off-server.
- Separate staging.

---

## 2. Configuration Checklist (per environment)

> Values are never committed. `.env` is git-ignored (verified). Only `.env.example` documents keys.

| Key / setting | Production | Staging | Check |
|---|---|---|---|
| `APP_ENV` | `production` | `staging` | TC-1401-01 |
| `APP_DEBUG` | **`false`** (DEF-15) | `false` | Boot guard (US-0104) |
| `APP_KEY` | Unique per environment | Unique | Present |
| `APP_URL`, `FRONTEND_URL` | HTTPS URLs | HTTPS URLs | — |
| `DB_*` | Production DB user with least privilege | Staging DB | Not the test DB |
| `SANCTUM_EXPIRATION` | 43200 min (30 days) | Same | US-0104 |
| CORS allowed origins | The production web origin only | The staging origin | No `*` |
| `LOG_CHANNEL` / level | Daily files, `warning`+ | `debug` | No secrets logged |
| `QUEUE_CONNECTION` | `database` (or redis) + worker | Same | Worker running |
| OTP driver + credentials | Production provider | Provider sandbox or `log` | US-0203 |
| AI provider key (R1.1) | Server only | Sandbox key | Never in the SPA or APK |
| Feature flags | `OTP_REQUIRED=true`, `AI_ENABLED` (R1.1), `SYNC_ENABLED` (R2) | Same | — |
| React `VITE_API_URL` | Production API | Staging API | Build-time |
| Flutter `API_BASE_URL` | Per flavor (staging, production) | — | Build-time (`--dart-define`) |

---

## 3. Safe Migration Procedure

All schema changes are **additive** ([05](05-data-model-and-api-contracts.md)). Procedure for each deployment that includes migrations:

1. **Pre-check (staging first):**
   - run `php artisan migrate --pretend` and review the SQL;
   - run the migration tests in CI (MySQL).
2. **Backup:** take an on-demand production DB backup and verify its size and timestamp. If the backup fails, the deployment stops.
3. **Maintenance window (if A-02 no longer holds):** `php artisan down` with a secret bypass; a short window, announced.
4. **Migrate:** `php artisan migrate --force`.
5. **Verify backfills:** run `hisbah:verify-stock` and the backfill assertion commands. They must report zero mismatches.
6. **Smoke test** (§5). If it fails, roll back (§6).
7. **Up:** `php artisan up`.

**Never** run `migrate:fresh`, `migrate:reset` or `db:wipe` outside the test database.

---

## 4. Release Procedure

| Step | R1 | R1.1 | R2 |
|---|---|---|---|
| 1 | All stories Done; G-S gates passed | Same | Same |
| 2 | Tag `v1.0.0-rc.N` → deploy to staging | `v1.1.0-rc.N` | `v2.0.0-rc.N` |
| 3 | Staging: migrations (§3), smoke (§5), UAT (US-1403), performance (US-1404) | + AI evaluation and safety suite | + device sync tests (US-1405) |
| 4 | Release gate G-R1 ([09 §9](09-testing-and-definition-of-done.md#9-release-gates)) signed by the TL | G-R1.1 | G-R2 |
| 5 | Production deploy (§3) → smoke → tag `v1.0.0` | Same | Same |
| 6 | Android: signed APK to the internal testing track → pilot devices | Same | Same + staged rollout |
| 7 | Release notes + known limitations published | Same | Same |
| 8 | Post-release watch: error logs daily for one week; defects triaged (P0–P3) | Same | Same |

**Known limitations to state in the R1 notes:**

- No offline selling (R2).
- No AI assistant (R1.1).
- No secure customer link or WhatsApp sharing (R1.1).
- Returns and stock adjustments are web-only.
- Integer quantities only.

---

## 5. Smoke Tests

Run after every staging or production deployment, using a dedicated **test store**, never a real shop.

1. `GET /up` returns 200; an HTTPS redirect is in place.
2. Login as the test owner → `GET /api/v1/me` shows the test store.
3. `GET /api/v1/dashboard?period=today` → 200, with the expected shape.
4. Create a product → sell 1 unit (cash) with an Idempotency-Key → replay with the same key gives the same response → void the sale → stock restored.
5. Cross-store probe with a second test store → 404.
6. React: load the login page and dashboard; check the browser console for errors.
7. Mobile (release build): log in, then scan a test barcode.
8. (R1.1) AI: ask a read question in the test store, then create and cancel a draft.
9. (R2) Queue one offline sale on a test device → reconnect → synced once.

Results are recorded in the release notes.

---

## 6. Rollback

| Situation | Action |
|---|---|
| Smoke test fails, and the release has **no** migrations | Redeploy the previous tag |
| Smoke test fails **after** additive migrations | Redeploy the previous tag. Additive columns and tables are ignored by the old code. Run `migrate:rollback` **only** for the release's migrations, and only if they block the old code (tested `down()`). |
| Data corruption detected | Put the app in maintenance mode → restore the pre-deployment backup to staging → compare → restore to production if confirmed (TL decision) → post-mortem |
| Mobile release defect | Halt the rollout; previous APK remains; the API stays backward-compatible for one version |
| Feature-specific failure (OTP, AI, sync) | Disable via its feature flag; fix forward |

---

## 7. Backup and Recovery (NFR-16)

- **Schedule:** automated daily full backup, plus an on-demand backup before each migration.
- **Retention and location:** ≥ 14 days, off-server.
- **Restore drill:** performed and documented before R1 (US-1402), then quarterly. The drill compares row counts and a financial checksum (Σ invoices, Σ payments, Σ debts remaining).
- **Runbook:** `docs/ops/restore-runbook.md`, written in S6 with the actual hosting commands.

---

## 8. Post-Release Defect Handling

| Priority | Response |
|---|---|
| P0 (financial corruption, data exposure) | Hotfix branch → fix + regression test → staging smoke → production within 24 h; affected records reviewed and corrected through controlled workflows (void, return, reversal), never by direct SQL edits |
| P1 | Next patch release |
| P2 / P3 | Planned into the next sprint or backlog |

Every defect gets a DEF-ID, the affected FR, UC or NFR, and a regression test.
