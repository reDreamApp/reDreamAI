# 0001 — Single Postgres (self-hosted Supabase's)

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Legacy `infra/docker-compose.yml` runs `postgres:15` as a standalone container for the backend, separate from the Supabase Postgres that handles auth + storage. Two clusters means two backup stories, two migration tools, and connection-string sprawl. With self-hosted Supabase already in the stack, this duplication has no payoff.

## Decision
Run a single Postgres — the self-hosted Supabase one. Backend connects via its `DATABASE_URL` to that same cluster. Application schema lives alongside Supabase's auth/storage schemas (different namespaces) and is managed by `supabase/migrations/*.sql` via the Supabase CLI.

## Consequences

### Positive
- Single backup/restore story.
- Single migration tool (Supabase CLI).
- No `db` service to maintain in `infra/docker-compose.yml`.
- `auth.users` ↔ `public.users` joins are trivial at the SQL level.

### Negative
- Backend and Supabase share resource pool; a runaway query on one affects the other. Mitigation: connection pooling + per-role connection limits.
- A Supabase upgrade is coupled with backend uptime. Mitigation: planned maintenance windows.

## Alternatives considered
- **Two Postgres clusters (legacy default)**: cleaner isolation, more ops. Rejected — unnecessary at current scale.
- **Backend connects via PostgREST instead of direct SQL**: rejected — non-trivial async SQLAlchemy patterns and many-table joins; direct SQL is cleaner.
- **Alembic for backend schema (legacy intent)**: rejected — `alembic.ini` was empty, never wired. Supabase CLI is one tool for the whole project.
