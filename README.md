# reDreamAI

Self-help mobile app based on CBT / IRT (Imagery Rehearsal Therapy) for processing nightmares. *Not a substitute for psychotherapy.*

## Repository layout

```
apps/
  ai/        Python FastAPI (stateless): chat, safety classifier, TTS, STT
  api/       Python FastAPI + async SQLAlchemy: source of truth for users, chats, dreams
  app/       Flutter (FVM 3.35.5): iOS + Android client, EN + DE

supabase/
  migrations/    SQL migrations (managed by Supabase CLI, single Postgres)

infra/
  terraform/            OpenTofu config for the Scaleway box: instance, firewall, runtime key, backup bucket
  bootstrap.sh          One-time setup of that box: Supabase, env files, migrations, stack, backups
  docker-compose.yml    Scaleway production topology: caddy + api + ai + langfuse
  caddy/                Reverse proxy config (TLS, SSE-friendly)

docs/
  decisions/    Architecture Decision Records (binding)
```

## Runtime flow

```
Flutter app
   ↓ HTTPS + SSE (Caddy)
apps/api  ← source of truth (chats, dreams, safety events, daily mood)
   ↓ HTTPS
apps/ai   ← stateless: receives full history, returns next IRT stage + response
   ↓
Scaleway Generative APIs (chat, speech-to-text), Mistral (fallback, text-to-speech)
```

## Quickstart (local)

```bash
cp apps/app/.env.example apps/app/.env   # the app bundles .env as an asset; needed before build/test
make help                  # list everything
make ai-dev                # run AI service locally on :8080
make api-dev               # run backend on :8001
make app-run               # flutter run via FVM
make test                  # all test suites
make up                    # full local stack via docker compose
```

## Deploy

One Scaleway instance runs the whole backend. From an empty account to a
working API in three steps: `tofu apply` in `infra/terraform`, copy the repo to
the box, run `infra/bootstrap.sh` there. The steps, what they create and what
ends up public are in [`infra/README.md`](infra/README.md).

## Decisions

Binding architectural decisions live in [`docs/decisions/`](docs/decisions/README.md). Read those before making structural changes.

Key invariants:
- One Postgres (self-hosted Supabase's). No standalone `db` container.
- AI service is stateless — every request carries the full conversation history.
- Structured outputs (JSON mode) for the summary. No string-matching parsers.
- Self-help framing, never therapy. Disclaimer copy required on user-facing surfaces.
- Crisis detection runs before every IRT turn; high-risk input bypasses the LLM.
- 100k LLM tokens / user / day (UTC reset).
- Streaming chat end-to-end via SSE.
- Pinned model IDs — no floating aliases (one recorded exception, ADR 0010).

## License

[Apache License 2.0](LICENSE).
