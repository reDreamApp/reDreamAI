# Supabase

Self-hosted Supabase is the **single Postgres** for this project (ADR 0001). It owns:
- `auth.*` (Supabase-managed)
- `storage.*` (Supabase-managed)
- `public.*` (our app schema — migrations live here)

## Migrations

```bash
make db-new-migration NAME=add_safety_events
# edits supabase/migrations/<timestamp>_add_safety_events.sql
make db-migrate                    # applies pending migrations locally
```

Migration files are committed; production deploy runs them via the Supabase CLI on the Scaleway host.

Do **not** add Alembic, Atlas, or any other migration tool. One source of truth for schema (ADR 0001).
