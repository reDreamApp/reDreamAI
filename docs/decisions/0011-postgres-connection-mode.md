# 0011 — Postgres connection mode: Supavisor transaction pooler (6543) everywhere

- Status: accepted (revised 2026-06-12 — see "Revision" below)
- Date: 2026-06-10
- Deciders: Daniel

## Context
Supabase exposes two ways to reach the project Postgres:
- **Direct** — `db.<project-ref>.supabase.co:5432`. One TCP connection per backend connection. Supports all Postgres features (LISTEN/NOTIFY, prepared statements, session-scoped temp tables). **On projects created after early 2024 the `db.*` hostname only has an AAAA (IPv6) record; an IPv4 record requires the paid "IPv4 add-on".**
- **Transaction pooler** (Supavisor) — `aws-<n>-<region>.pooler.supabase.com:6543`. Multiplexes many client connections onto fewer DB connections in **transaction mode**. Available on both IPv4 and IPv6, included in all paid and free tiers. Disables prepared-statement caching and session-scoped features.

## Decision
Use the **Supavisor transaction pooler** (`pooler.supabase.com:6543`) as the `DATABASE_URL` for **both** local dev and deployed environments.

The `asyncpg` driver must be configured with `statement_cache_size=0` because transaction-mode pooling rotates the underlying DB connection between transactions, invalidating prepared statements. This is set in `apps/api/src/redream_api/db/session.py` via `connect_args` on the SQLAlchemy engine.

## Consequences

### Positive
- Works from IPv4-only networks (most home ISPs, café WiFi, many corp networks) without buying the IPv4 add-on.
- Same URL form locally and in production — fewer "works on my machine" issues.
- Production-grade connection scaling out of the box; no day-1 surprise when traffic grows.

### Negative
- No prepared-statement cache → each query is re-parsed/re-planned. Negligible at our query volume, measurable only under heavy load.
- LISTEN/NOTIFY and session-scoped temp tables don't work over the pooler. We don't use either today; if we ever need them, route those specific operations through a session-mode pool (port 5432-pool variant) rather than abandoning Supavisor.
- The pooler URL embeds region + project ref in the username (`postgres.<ref>`), which looks unusual. Document in `apps/api/.env.example`.

## Alternatives considered
- **Direct connection (5432) for local, pooler for prod** (original decision, now superseded). Rejected because new Supabase projects only expose IPv6 on the direct host, breaking local dev for anyone without working IPv6. The Mac dev environment that triggered this revision hit `socket.gaierror` on the direct host and worked immediately on the pooler.
- **Buy the IPv4 add-on** so the direct host resolves on IPv4. Rejected — recurring cost for a workaround when the pooler is free and works.
- **Session-mode pooler** (port 5432-pool variant). Rejected for now — transaction mode is the Supabase-recommended default; revisit only if we genuinely need session features.

## Revision history
- **2026-06-10**: Original decision was "direct for local, pooler for deployed."
- **2026-06-12**: Revised after discovering the `db.*` host on this project is IPv6-only. New rule: pooler everywhere. The original decision's reasoning ignored the IPv6-only direct host on post-2024 projects.
