# Owner actions

In order. Nothing here was done for you: each needs your decision, your credentials, or touches
production / Play Console.

## A. Before merging this branch
1. **Review the uncommitted changes** in `micro-erp-system.worktrees/release-readiness`
   (`git status`, `git diff`). Then commit/PR when satisfied.
2. Decide plan **prices, currencies, features, limits** (SUBSCRIPTION_ARCHITECTURE.md). Plans ship
   inactive and unpriced; set them at `/admin/subscriptions → الباقات` after deploy.

## B. Deploy (when you choose to)
1. Dispatch the `hisbah-db-backups` workflow and confirm it succeeded (your rule before migrations).
2. Deploy the API, then run migration `2026_11_09_000001_create_subscriptions_payments_and_deletion`
   on production (adds tables + columns, backfills `trial_started_at` and one `trial_claims` row per
   existing owner; changes no trial dates).
3. Render env: `HISBAH_TRIAL_DAYS=14` (render.yaml updated), `WHATSAPP_BUSINESS_NUMBER=<your WhatsApp
   Business number>`, optional `CORS_ALLOWED_ORIGINS`. Leave all `*_ENABLED` payment flags false.
4. **Scheduler:** two new hourly jobs (`hisbah:subscription-reminders`, `hisbah:process-deletions`) and
   the existing `idempotency:prune` need `php artisan schedule:run` every minute/hour. Render's free
   web service has no cron — add a Render Cron Job (paid) or a GitHub Actions schedule that calls a
   protected endpoint/one-off command. **Without it, owner-requested store closures are never
   executed** after the grace period.
5. Deploy the website (Vercel). Check `/delete-account` loads publicly.
6. Full Shorebird **release** (not a patch): the Android manifest changed (backups off, Bluetooth
   flags) and new screens were added.

## C. Security (from SECURITY_AUDIT.md)
1. **APP_KEY check (UNVERIFIED — I was not permitted to read production config).** On your PC run
   `node docs/release-readiness/tools/appkey_fingerprint.mjs backend/.env.testing srv-db94et7t5n8s73auto80`
   — it prints fingerprints only. If production equals the test key (`a605b87b8af22117`): rotate.
   **Rotation consequences:** encrypted values and signed URLs/cookies become unreadable, all sessions
   end, and `trial_claims` hashes stop matching (set `APP_PREVIOUS_KEYS` for decryption and re-hash
   claims in a one-off command before switching).
2. **Encrypt database backups.** In `hisbah-db-backups`, pipe the dump through `age` before commit:
   `mysqldump … | gzip | age -r "$AGE_PUBLIC_KEY" > backups/…sql.gz.age`. Only the **public** key goes
   into GitHub secrets; keep the private key offline (two copies). Then decide history: existing
   plaintext dumps stay in git history until you rewrite that repo's history (force-push — needs your
   explicit decision) or delete and recreate the repo. Rotate the DB password afterwards if the repo
   was ever shared.
3. Verify the client IP Laravel sees on Render (one `audit_logs.ip` after deploy). If it is a proxy
   address, the per-IP limiters are shared; they are now keyed per number too, so one abuser no longer
   blocks everyone, but tell me what you see before trusting any forwarded header.
4. After a week of no CSP reports on the website, switch `Content-Security-Policy-Report-Only` to
   enforcing in `frontend/vercel.json`.
5. Check Aiven grants: the runtime account should not have DDL rights if possible.

## D. Legal
Fill LEGAL_INFORMATION_REQUIRED.md, legal review, publish Privacy Policy + Terms (Arabic + English)
on public HTTPS pages, build the app with `--dart-define=PRIVACY_POLICY_URL=https://…` so the
«سياسة الخصوصية» row appears.

## E. Payments
Pick a provider (PalPay / Jawwal Pay / Bank of Palestine), get official integration docs and sandbox
credentials, then follow PAYMENT_INTEGRATION_GUIDE.md. Until then: WhatsApp requests + manual
confirmation only.

## F. Google Play (PLAY_CONSOLE_CHECKLIST.md)
1. Account type: personal account created after 13 Nov 2023 → **closed test, ≥ 12 testers, 14
   continuous days** before production access. Check in Play Console → Dashboard (I cannot see it).
2. Play App Signing: choose "use existing app signing key" (upload the current release key via PEPK)
   so website installs can update from Play; create a new upload key. Irreversible.
3. Reviewer demo store on production with an **active** subscription (set via admin), password-only
   sign-in (SMS off).
4. Data safety, content rating, target audience, ads (none), financial features, store listing,
   privacy URL, account deletion URL.

## G. Testing you must do on hardware
Real Android phones (Android 8, 12+, 14+; small and large screens): scanner, sale, debts, offline
sync, delete-account flow, and **Bluetooth printing on Android 12+** (permission fix is untested on a
printer).
