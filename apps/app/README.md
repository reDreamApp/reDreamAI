# apps/app — reDreamAI Flutter client

Flutter mobile app (iOS + Android). Talks to `apps/api`, which talks to `apps/ai`.

## Setup

```bash
fvm use                       # Flutter version pinned in .fvmrc
fvm flutter pub get           # also generates lib/l10n/generated/
cp .env.example .env          # then fill in SUPABASE_* and API_BASE_URL
```

## Run / check

```bash
fvm flutter run
fvm flutter analyze
fvm flutter test
fvm dart format .
```

Backend dev URL: `http://localhost:8001` (iOS simulator / desktop),
`http://10.0.2.2:8001` (Android emulator). Sign-in goes straight to Supabase;
the API verifies the resulting JWT.

## Layout

```
lib/
  main.dart            bootstrap + dependency wiring
  app.dart             MaterialApp, theme/locale, AuthGate
  core/                app-wide plumbing, no feature knowledge
    api/               ApiClient (JSON, bearer token, 401 refresh, error mapping)
    auth/              AuthService (Supabase session as a ChangeNotifier)
    settings/          AppSettings (theme mode, language, onboarding flag)
    storage/           LocalStore (shared_preferences as JSON key/value)
    theme/             brand palette, BrandTheme extension, light/dark ThemeData
    widgets/           AppCard, AppButton, BrandLogo, ThemeModeToggle, IntensitySlider, snackbars/dialogs
    utils/             error → message mapping, date formatting
  features/            one folder per feature: models, service (HTTP), state (ChangeNotifier), screens
    shell/             MainShell (app bar, 3 tabs, chat drawer), UserScope (per-user providers)
    home/              home tab, progress stats + mood, IRT guide
    chat/              Session tab: ChatState, bubbles, stage indicator, history drawer, reports
    journal/           dreams: offline-capable JournalState, cards, detail, editor, practice (reading/audio)
    reminders/         daily local notification + settings tile
    settings/          profile, account (email/password/export/delete), help center, privacy policy
    auth/              sign in / sign up / forgot password
    onboarding/        post-sign-up intro + profile questions
    learn/             blog articles from the website's meta.json
  l10n/                app_en.arb / app_de.arb (every user-facing string)
```

Rules of thumb:

- Screens only read/watch a `*State` and call its methods; states own the
  data and call a `*Service`; services only talk HTTP through `ApiClient`.
- Per-user state lives under `UserScope`, keyed by user id, so signing out
  disposes it and signing in starts clean.
- Offline: the journal caches the last server list and queues drafts and
  practices in `LocalStore`; `JournalState.syncPending()` flushes them on the
  next refresh or app resume. Chat keeps the last failed message for resend.
- `flutter test` covers `ApiClient`, `JournalState`, `ChatState` and the main
  screens against an in-memory fake API (`test/fake_api.dart`).
