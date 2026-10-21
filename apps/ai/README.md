# apps/ai — IRT chatbot + crisis classifier + Voxtral audio

Stateless Python service. Receives the full conversation history per request and returns the next IRT stage + response.

## Endpoints

- `POST /chat` — IRT routing + response, non-streaming
- `POST /chat/stream` — same turn as SSE (ADR 0009); frame contract lives in `src/redream_ai/api/chat.py`'s module docstring
- `POST /safety/classify` — crisis pre-classifier; backend calls this **before** `/chat` (ADR 0005)
- `POST /audio/transcribe` — Voxtral STT for voice journaling (ADR 0010)
- `POST /rehearsal/generate` — Voxtral TTS for audio rehearsal; uploads to Supabase Storage
- `GET /health` — liveness probe

## Local dev

```bash
cp .env.example .env       # fill in the API keys
uv sync
make ai-dev                # from repo root, or:
uv run uvicorn redream_ai.main:app --reload --port 8080
```

`SCALEWAY_API_KEY` **and** `MISTRAL_API_KEY` are both required for `/chat` (Scaleway primary, direct-Mistral fallback). `LANGFUSE_*` is optional; `LANGFUSE_ENABLED=false` is the tracing off-switch.

## Tests

```bash
make ai-test
```

Tests run fully offline (`FakeLlmClient` + monkeypatched core agents) — no live calls, no API keys required.

## Architecture

- `redream_ai.core` — ported IRT chatbot engine (routing + response agents, Scaleway primary with direct-Mistral fallback). Chat/routing/safety-critic model IDs are pinned in `core/agent.py::MODELS` — see ADR 0010's 2026-07-01 amendment, don't duplicate them elsewhere.
- `redream_ai.clinical_safety` — neuro-symbolic `SafetyCritic`; runs inside the core during the rewriting stage.
- `redream_ai.api` — FastAPI routes (`chat`, `safety`, `audio`, `health`).
- `redream_ai.llm` — `LlmClient` protocol + Scaleway/Mistral/fake adapters; now used only by the crisis classifier route.
- `redream_ai.safety.classifier` — JSON-mode crisis classifier: Mistral Small 3.2 on Scaleway, Ministral 8B on direct Mistral as fallback.
- `redream_ai.audio.tts` — Voxtral TTS + Supabase Storage upload (stubbed pending voice source).
- `redream_ai.audio.stt` — Voxtral STT (stubbed pending Mistral SDK wiring).

See [`../../docs/decisions/`](../../docs/decisions/README.md) for the binding architectural decisions.
