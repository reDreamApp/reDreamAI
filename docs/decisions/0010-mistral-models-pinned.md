# 0010 — Pinned Mistral / Voxtral model IDs

- Status: accepted (chat/routing/safety models **amended 2026-07-01** — see Amendment below)
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

## Amendment (2026-07-01) — Scaleway-primary chat topology from the ported chatbot core

The IRT chatbot core was replaced by the richer engine ported from the SU Streamlit
prototype (neuro-symbolic clinical safety, cross-provider fallback, logprob classifier).
That engine is built for **Scaleway as the primary provider with direct Mistral as a
cross-provider fallback** — a resilience property (Scaleway occasionally drops connections
under load) the original single-provider decision lacked. The pinned-dated-ID principle is
unchanged; the specific IDs and providers for the **chat / routing / safety** roles are
superseded as follows (Voxtral TTS/STT rows above are unchanged):

| Role | Primary (Scaleway) | Fallback (direct Mistral) | Logprobs |
|---|---|---|---|
| Response (IRT chat) | `mistral-medium-3.5-128b` | `mistral-medium-latest`¹ | no |
| Stage routing | `mistral-small-3.2-24b-instruct-2506` | `ministral-8b-2512` | no |
| Safety segmenter | `mistral-small-3.2-24b-instruct-2506` | `ministral-8b-2512` | no |
| Safety classifier | `mistral-small-3.2-24b-instruct-2506` | `mistral-small-2603` | **yes** |

The classifier's fallback is deliberately `mistral-small-2603` (not `ministral-8b`) because
the logprob-based confidence gate needs a fallback that returns logprobs.

¹ **Amended 2026-07-02:** the response fallback moved from `mistral-large-2512` to
`mistral-medium-latest` — a deliberate, recorded **exception** to this ADR's floating-alias
ban (explicit user decision): the fallback only serves when the Scaleway primary fails, and
tracking Mistral's current medium keeps its behaviour close to the pinned primary instead of
aging out on a fixed version. Accepted risk: Mistral can silently change what the alias
serves. The primary and all other roles stay pinned.

These IDs live in the ported `redream_ai/core/agent.py::MODELS` registry (pinned; a typo
fails `tests/test_ported_core.py`). Base URLs `https://api.scaleway.ai/v1` and
`https://api.mistral.ai/v1` are load-bearing.

**Config change:** `SCALEWAY_API_KEY` is now **required** alongside `MISTRAL_API_KEY`. The
old `MISTRAL_RESPONSE_MODEL` / `MISTRAL_ROUTING_MODEL` (`mistral-small-4-0-26-03`,
`ministral-8b-2512`) drove the retired core and no longer apply to the chat path.

**`reasoning_effort`:** not sent by the ported core (the old "response model uses
`reasoning_effort=low`" note above no longer applies to chat). If reintroduced, it must be a
per-model capability flag stripped from the fallback kwargs — the Mistral fallback models
likely don't support it (see integration brief §3).
