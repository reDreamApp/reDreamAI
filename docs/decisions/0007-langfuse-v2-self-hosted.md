# 0007 — Self-hosted Langfuse v2 (not cloud, not v3)

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Legacy AI service has Langfuse spans via `@observe` decorators, pointing at `LANGFUSE_HOST` (default cloud). Cloud Langfuse routes traces — which include therapy conversation contents — to a US-hosted service. For an EU-resident mental-health adjacent app this is problematic.

Langfuse v3 requires Clickhouse for trace storage. v2 is Postgres-only.

## Decision
Run Langfuse v2 as a service alongside `api` + `ai` in `infra/docker-compose.yml`. Use the same Supabase Postgres (carve a `langfuse` database). No Clickhouse, no v3.

The GDPR erasure path (currently a no-op stub in legacy `langfuse_service.py`) must actually implement: when a user requests data deletion, delete their Langfuse traces by `user_id` tag.

## Consequences

### Positive
- All LLM observability stays EU-resident.
- One less external dependency to monitor, at the cost of one more container to run.
- Same Postgres backup strategy covers Langfuse traces.

### Negative
- Langfuse v3 has features (advanced eval, dataset management) we won't have. Acceptable for v1.
- One more container = one more thing to upgrade. Pin to a known-good v2 tag in compose.

## Alternatives considered
- **Langfuse cloud**: rejected (EU residency).
- **Langfuse v3 self-hosted**: adds Clickhouse + more ops. Not justified at current scale.
- **No tracing**: rejected — therapy conversation quality regressions are hard to catch without trace-level introspection.
