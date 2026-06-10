# apps/app — reDreamAI Flutter client

Flutter mobile app (iOS + Android). Talks to `apps/api` which talks to `apps/ai`.

## Setup

```bash
# Flutter version is pinned via FVM (see .fvmrc → 3.35.5)
fvm use                       # ensures the SDK is available
fvm flutter pub get
cp .env.example .env          # then fill in SUPABASE + API_BASE_URL
```

## Run

```bash
fvm flutter run               # default device

# or via the repo Makefile (from repo root)
make app-run
```

## Common commands

```bash
fvm flutter analyze           # lint
fvm flutter test              # widget + unit tests
fvm dart fix --apply          # apply lint fixes
fvm dart format .             # format
```

## Backend dev URL

- iOS simulator / desktop: `http://localhost:8001`
- Android emulator: `http://10.0.2.2:8001`

The backend (`apps/api`) verifies the Supabase JWT we send, so you need a valid
session — the sign-in screen calls `supabase_flutter` directly against your
self-hosted Supabase. Unauthenticated requests get 401.

## Architecture

This is a thin vertical slice (auth → chat → IRT) intentionally — the rest of
the legacy frontend (collection, learn, profile, onboarding, recording,
progress, help-center) is ported on top once the wire contract with `apps/api`
is proven. See `lib/features/` for what's implemented.

State management: Provider. Local cache: none yet (memory + REST). Auth:
`supabase_flutter`. HTTP: `package:http`. i18n: gen_l10n (`lib/l10n/`).
