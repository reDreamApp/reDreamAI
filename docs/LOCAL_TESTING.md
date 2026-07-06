# Local testing — simulators + local Supabase

How to run the full stack against a **local, throwaway database** (no cloud
Supabase, no production) and smoke-test the app on iOS and Android simulators.
Set up 2026-07-05.

## The test database (local Supabase via Docker)

The repo is a Supabase CLI project (`supabase/config.toml`). The local stack
runs entirely in Docker and applies `supabase/migrations/` on start — schema
parity with production comes for free.

```bash
# Prereqs: Docker Desktop running; supabase CLI (installed in the
# `dreamapp_env` conda env: /opt/miniconda3/envs/dreamapp_env/bin)
supabase start          # first run pulls images; later runs are seconds
supabase status         # prints URLs + keys
supabase stop           # stop containers (keeps data)
supabase db reset       # wipe + re-apply migrations (fresh test DB)
```

Fixed local endpoints (CLI demo defaults — public knowledge, not secrets):

| What | Value |
|---|---|
| API / auth | `http://127.0.0.1:54321` |
| Postgres | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio | `http://127.0.0.1:54323` |
| Mail catcher (Mailpit) | `http://127.0.0.1:54324` |
| JWKS | `http://127.0.0.1:54321/auth/v1/.well-known/jwks.json` |

Local GoTrue signs access tokens with **ES256 + kid** and publishes the JWKS,
so `apps/api`'s strict JWKS verification works unchanged — only `.env` URLs
differ from cloud.

### Test user

`test@local.dev` / `Test-12345-chat` — created via the admin API (survives
`supabase stop`, wiped by `supabase db reset`):

```bash
SRK=<SERVICE_ROLE_KEY from `supabase status`>
curl -X POST http://127.0.0.1:54321/auth/v1/admin/users \
  -H "apikey: $SRK" -H "Authorization: Bearer $SRK" \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@local.dev","password":"Test-12345-chat","email_confirm":true}'
```

## Env files

`apps/api/.env` and `apps/app/.env` currently point at the local stack.
Variants (all gitignored):

- `apps/api/.env.cloud.bak`, `apps/app/.env.cloud.bak` — the previous cloud
  Supabase config (NOTE: that project ref was NXDOMAIN as of 2026-07-05).
- `apps/app/.env.android.bak` — local stack as seen from the **Android
  emulator**: host is `10.0.2.2`, not `localhost`. `cp` it over `.env` before
  an emulator build; Flutter bundles `.env` as an asset at **build time**, so
  a rebuild is required after swapping.

`apps/ai/.env` is unchanged (real Mistral/Scaleway keys; the AI service is
stateless and DB-free — its Supabase storage config is only used for
rehearsal audio).

## Running the services

```bash
cd apps/ai  && uv run uvicorn redream_ai.main:app  --port 8080
cd apps/api && uv run uvicorn redream_api.main:app --port 8001
# health: :8080/health and :8001/api/v1/health
```

## The live smoke test (both platforms)

`apps/app/integration_test/live_smoke_test.dart` drives the real app: signs in
as the test user, opens the chat tab, sends a message, and waits (≤120 s) for
the streamed AI reply. It hits the **real LLM** — it is deliberately not part
of `flutter test` / CI.

Two things the test does that look odd but are load-bearing:

- It seeds **in-memory SharedPreferences** with `onboarding_seen=true` before
  launch. HomeScreen pushes the first-run onboarding **fullscreen** one frame
  after sign-in; the opaque route puts MainScreen offstage and every widget
  finder silently stops matching. The in-memory prefs also drop any persisted
  Supabase session, so each run signs in fresh.
- It switches tabs through `TabNavigator` instead of tapping the nav bar —
  a missed tap otherwise strands the run on the home tab.

```bash
cd apps/app
# iOS (localhost .env):
fvm flutter test integration_test/live_smoke_test.dart -d <ios-sim-udid> --timeout none

# Android (swap env first, then rebuild):
cp .env.android.bak .env
fvm flutter test integration_test/live_smoke_test.dart -d emulator-5554 --timeout none
cp .env.ios.bak .env    # or restore whichever variant you need
```

Simulators:
- iOS: `xcrun simctl list devices available` (any iPhone 17 device works).
- Android: AVD `dreamapp_test` (Pixel 7, API 36) —
  `/opt/homebrew/share/android-commandlinetools/emulator/emulator -avd dreamapp_test`
  with `JAVA_HOME=/opt/miniconda3/envs/dreamapp_env/lib/jvm`.
  Debug builds allow cleartext HTTP via `app/src/debug/AndroidManifest.xml`
  (`usesCleartextTraffic` — debug-only, not in release).

## Gotchas

- **Local ≠ load-bearing:** all keys/JWT secrets above are the CLI's shared
  demo defaults. Never reuse them outside `supabase start`.
- **macOS TCC:** Claude Code / terminals need the "Documents Folder"
  permission to touch this repo; a revocation manifests as
  `Operation not permitted` on every file. Toggle in System Settings →
  Privacy & Security → Files and Folders, then fully restart the app.
- The Android SDK lives in `/opt/homebrew/share/android-commandlinetools`
  (pre-existing); emulator + platform-tools + the API 36 system image were
  added 2026-07-05. Dev tooling (JDK, OpenTofu, supabase CLI) lives in the
  `dreamapp_env` conda env.
