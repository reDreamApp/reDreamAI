# reDreamAI

Self-help mobile app based on CBT / IRT (Imagery Rehearsal Therapy) for processing nightmares. *Not a substitute for psychotherapy.*

## Repository layout

```
apps/
  ai/        Python FastAPI + Mistral (stateless): chat, safety classifier, TTS, STT
  api/       Python FastAPI + async SQLAlchemy: source of truth for users, chats, dreams
  app/       Flutter (FVM 3.35.5): iOS + Android client, EN + DE

supabase/
  migrations/    SQL migrations (managed by Supabase CLI, single Postgres)

infra/
  docker-compose.yml    Scaleway production topology: caddy + api + ai + langfuse
  caddy/                Reverse proxy config (TLS, SSE-friendly)

docs/
  decisions/    Architecture Decision Records (binding)

data/
  helplines.json    Crisis-detection helplines, consumed by api + app
```

## Runtime flow

```
Flutter app
   ↓ HTTPS + SSE (Caddy)
apps/api  ← source of truth (chats, dreams, safety events, daily mood)
   ↓ HTTPS
apps/ai   ← stateless: receives full history, returns next IRT stage + response
   ↓ Mistral API
Mistral (Small 4, Ministral 8B, Voxtral TTS/STT)
```

## Quickstart (once scaffolding lands)

```bash
make help                  # list everything
make ai-dev                # run AI service locally on :8080
make api-dev               # run backend on :8001
make app-run               # flutter run via FVM
make test                  # all test suites
make up                    # full local stack via docker compose
```

## Decisions

Binding architectural decisions live in [`docs/decisions/`](docs/decisions/README.md). Read those before making structural changes.

Key invariants:
- One Postgres (self-hosted Supabase's). No standalone `db` container.
- AI service is stateless — every request carries the full conversation history.
- Structured outputs (JSON mode) for routing and summary. No string-matching parsers.
- Self-help framing, never therapy. Disclaimer copy required on user-facing surfaces.
- Crisis detection runs before every IRT turn; high-risk input bypasses the LLM.
- 100k LLM tokens / user / day (UTC reset).
- Streaming chat end-to-end via SSE.
- Pinned Mistral model IDs in env — never floating aliases.

## Legacy

The previous monorepo lives under `legacy_repos/` (frozen, reference only). Do not modify; port piece by piece into `apps/` per the ADRs.
