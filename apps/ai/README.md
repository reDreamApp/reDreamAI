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

## Architecture

- `redream_ai.llm.base` — `LlmClient` protocol; swap providers behind it.
- `redream_ai.llm.mistral_client` — Mistral SDK adapter (production).
- `redream_ai.llm.fake_client` — fake implementation for tests + offline dev.
- `redream_ai.irt` — IRT 5-stage state machine + guardrails.
- `redream_ai.safety.classifier` — Ministral 8B JSON-mode crisis classifier.
- `redream_ai.audio.tts` — Voxtral TTS + Supabase Storage upload (stubbed pending voice source).
- `redream_ai.audio.stt` — Voxtral STT (stubbed pending Mistral SDK wiring).

See [`../../docs/decisions/`](../../docs/decisions/README.md) for the binding architectural decisions.
