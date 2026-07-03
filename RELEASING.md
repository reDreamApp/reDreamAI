# Releasing

Decided 2026-07-02. Two long-lived branches, one release gate:

- **`main`** — development. The Supabase **Cloud** project (dev DB,
  `niypesvrzqkkylpnbksq`) is connected to this branch via the GitHub
  integration: a migration merged to main auto-applies to the dev DB.
  Pushing main never deploys anything.
- **`production`** — the release gate. Pushing it runs
  `.github/workflows/deploy.yml`, which rsyncs the repo to the Scaleway host,
  **applies pending migrations to the self-hosted Postgres first**, then
  `docker compose up -d --build`. Code and schema travel on the same ref, so
  the API can never start against a database missing its migration.

## How a schema change ships

1. Create it: `make db-new-migration NAME=feature_x`, edit the SQL, test
   locally (`make db-migrate` against the local stack, or a Supabase preview
   branch if on a paid plan — each PR touching `supabase/migrations/` gets an
   ephemeral database).
2. Merge to `main` → the Cloud dev DB gets it automatically.
3. Release: fast-forward `production` to main and push:
   `git push origin main:production`
   → migrations apply to the self-hosted DB, then containers rebuild.

## One-time setup (manual, Supabase dashboard + host)

- [ ] Supabase dashboard → project `niypesvrzqkkylpnbksq` → GitHub integration:
      connect to **`main`** (the previously connected `deploy` branch no longer
      exists — the integration is dangling until this is done).
- [ ] Create the branch: `git branch production && git push origin production`.
- [ ] On the Scaleway host: install the Supabase CLI and create
      `/srv/redreamai/infra/env/deploy.env` containing
      `SUPABASE_DB_URL=postgresql://postgres:<password>@localhost:5432/postgres`
      (host-only file; `infra/env/` is excluded from rsync and git).
      The CLI requires the connection string to be **percent-encoded** — if the
      password contains special characters (`@ : / # ?` …), encode them
      (e.g. `p@ss` → `p%40ss`) or the push fails with a parse error.
- [ ] Backfill: the dev DB predates the integration switch — apply any
      missing migrations once via the dashboard SQL editor or
      `supabase db push --db-url <dev-db-url>` (as of this doc:
      `20260511000001_initial.sql` status unverified, and
      `20260702000001_chats_nightmare_summary.sql` is new).

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
