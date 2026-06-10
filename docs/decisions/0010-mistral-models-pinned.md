# 0010 — Pinned Mistral / Voxtral model IDs

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Mistral exposes floating aliases (`mistral-small-latest`) and dated IDs (`mistral-small-4-0-26-03`). Floating aliases silently change underneath. For a clinical-adjacent app where prompt-model behaviour matters, that's a regression risk.

The legacy AI service uses Groq with `llama-3.1-8b-instant` + `llama-3.3-70b-versatile`. The rebuild swaps to Mistral entirely (EU residency + price + multilingual quality + Voxtral audio stack in the same provider).

## Decision
Pin exact dated model IDs in env, verified from Mistral docs on 2026-05-07:

| Role | Model ID | Endpoint |
|---|---|---|
| Response agent (IRT chat) | `mistral-small-4-0-26-03` | `/v1/chat/completions` |
| Routing agent + safety classifier | `ministral-8b-2512` | `/v1/chat/completions` |
| Routing fallback (if accuracy needs more) | `ministral-14b-2512` | `/v1/chat/completions` |
| TTS (rehearsal audio) | `voxtral-mini-tts-2603` | `/v1/audio/speech/complete` |
| STT (dream voice journaling) | `voxtral-mini-latest` (alias for `voxtral-mini-2507`) | `/v1/audio/transcriptions` |

Configuration in `apps/ai/.env`:

```
MISTRAL_RESPONSE_MODEL=mistral-small-4-0-26-03
MISTRAL_ROUTING_MODEL=ministral-8b-2512
MISTRAL_SAFETY_MODEL=ministral-8b-2512
VOXTRAL_TTS_MODEL=voxtral-mini-tts-2603
VOXTRAL_STT_MODEL=voxtral-mini-latest
```

The response model uses `reasoning_effort=low` for therapy turns to keep latency conversational.

## Consequences

### Positive
- Behaviour is reproducible across deploys.
- Model upgrades are a deliberate, reviewed change.
- Trace data in Langfuse is tagged with the actual model version, useful for regression analysis.

### Negative
- We won't auto-benefit from Mistral's "latest small" improvements. Acceptable — re-evaluate quarterly.
- The STT model intentionally uses `-latest` for now (Voxtral STT is newer, less risk in tracking). Revisit when v1 ships.

## Alternatives considered
- **Floating aliases**: rejected — see context.
- **OpenAI / Anthropic**: rejected — Mistral is EU-resident, price-competitive, and ships the Voxtral audio stack we need.
- **Self-hosted via vLLM**: out of scope for v1 (ops weight).
