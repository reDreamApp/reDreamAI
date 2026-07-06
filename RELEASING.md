# Releasing

Decided 2026-07-02 (amended 2026-07-06). Two long-lived branches, one release
gate:

- **`main`** — development. The dev database is the **local Supabase stack**
  (`supabase start`, see docs/LOCAL_TESTING.md); CI's `migrations` job proves
  every push applies `supabase/migrations/` cleanly from zero. Pushing main
  never deploys anything.
  *(2026-07-06: this replaces the original plan of wiring the Supabase Cloud
  project `niypesvrzqkkylpnbksq` to main via the dashboard GitHub integration —
  that free-tier project auto-pauses after inactivity (found paused, DNS gone),
  which makes it useless as an always-on dev DB or migration gate. It stays
  paused as a cold backup; restore via the dashboard if anything in it is ever
  needed.)*
- **`production`** — the release gate. Pushing it runs
  `.github/workflows/deploy.yml`, which rsyncs the repo to the Scaleway host,
  **applies pending migrations to the self-hosted Postgres first**, then
  `docker compose up -d --build`. Code and schema travel on the same ref, so
  the API can never start against a database missing its migration.

## How a schema change ships

1. Create it: `make db-new-migration NAME=feature_x`, edit the SQL, test
   locally against the local stack (`supabase migration up --local`, or
   `supabase db reset` for a from-zero check).
2. Merge to `main` → CI's `migrations` job re-proves the full chain applies
   from zero on the Supabase Postgres image.
3. Release: fast-forward `production` to main and push:
   `git push origin main:production`
   → migrations apply to the self-hosted DB, then containers rebuild.

## One-time setup (manual, host)

- ~~Supabase dashboard → GitHub integration to `main`~~ — superseded
  2026-07-06 by the CI `migrations` job (cloud project paused; see above).
- [ ] Create the branch: `git branch production && git push origin production`.
- [ ] On the Scaleway host: install the Supabase CLI and create
      `/srv/redreamai/infra/env/deploy.env` containing
      `SUPABASE_DB_URL=postgresql://postgres:<password>@localhost:5432/postgres`
      (host-only file; `infra/env/` is excluded from rsync and git).
      The CLI requires the connection string to be **percent-encoded** — if the
      password contains special characters (`@ : / # ?` …), encode them
      (e.g. `p@ss` → `p%40ss`) or the push fails with a parse error.
- ~~Backfill the Cloud dev DB~~ — moot since 2026-07-06 (cloud project
  demoted/paused; the local stack always builds from the full migration
  chain).

## Caveats

- First-ever deploy: the migration step needs the self-hosted Supabase stack
  (and its Postgres) already running on the host — bring that up before the
  first `production` push.
- Auth (`auth.*`) is Supabase-managed and works regardless of branch wiring;
  only `public.*` schema depends on migrations reaching the DB.
- `apps/api` tests don't need any of this (in-memory SQLite from the ORM
  models) — which is exactly why a missing migration surfaces only in a real
  environment. When you add a column to a model, the migration belongs in the
  same commit.
