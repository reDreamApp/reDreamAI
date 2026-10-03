# apps/ai — IRT chatbot + crisis classifier + Voxtral audio

Stateless Python service. Receives the full conversation history per request and returns the next IRT stage + response.

## Endpoints

- `POST /chat` — IRT routing + response (streaming SSE in v1, ADR 0009)
- `POST /safety/classify` — crisis pre-classifier; backend calls this **before** `/chat` (ADR 0005)
- `POST /audio/transcribe` — Voxtral STT for voice journaling (ADR 0010)
- `POST /rehearsal/generate` — Voxtral TTS for audio rehearsal; uploads to Supabase Storage
- `GET /health` — liveness probe

## Local dev

```bash
cp .env.example .env       # fill in MISTRAL_API_KEY etc.
uv sync
make ai-dev                # from repo root, or:
uv run uvicorn redream_ai.main:app --reload --port 8080
```

## Tests

```bash
make ai-test
```

Tests run against `FakeLlmClient` — no live Mistral calls, no API key required.

## Live evals
`evals/run_evals.py` runs fixed safety and routing cases against the real Mistral API (needs `MISTRAL_API_KEY`, not part of CI). Run it after changing a prompt or a model:

```sh
uv run python evals/run_evals.py
```

## Architecture

- `redream_ai.llm.base` — `LlmClient` protocol; swap providers behind it.
- `redream_ai.llm.mistral_client` — Mistral SDK adapter (production).
- `redream_ai.llm.fake_client` — fake implementation for tests + offline dev.
- `redream_ai.irt` — IRT 5-stage state machine + guardrails.
- `redream_ai.safety.classifier` — Ministral 8B JSON-mode crisis classifier.
- `redream_ai.chat.pipeline` — one `/chat` turn: routing agent (JSON) → `irt` guardrails → stage prompt; the summary stage answers in JSON and is returned as `structured`.
- `redream_ai.audio.tts` — Voxtral TTS, cached per content hash in the Supabase bucket, signed URL returned.
- `redream_ai.audio.stt` — Voxtral STT (`/audio/transcribe`).
- `redream_ai.audio.mistral_audio` / `supabase_storage` — the only modules touching the Mistral audio SDK and Supabase Storage.

See [`../../docs/decisions/`](../../docs/decisions/README.md) for the binding architectural decisions.
