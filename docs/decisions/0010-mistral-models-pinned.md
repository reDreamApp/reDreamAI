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
`https://api.mistral.ai/v1` are load-bearing. With `SCALEWAY_PROJECT_ID` set (2026-10-03)
the Scaleway URL becomes `https://api.scaleway.ai/{project_id}/v1`: the bare URL resolves to
the organization's default project and answers 403 to a key restricted to another one.

**Config change:** `SCALEWAY_API_KEY` is now **required** alongside `MISTRAL_API_KEY`. The
old `MISTRAL_RESPONSE_MODEL` / `MISTRAL_ROUTING_MODEL` (`mistral-small-4-0-26-03`,
`ministral-8b-2512`) drove the retired core and no longer apply to the chat path.

**`reasoning_effort`:** not sent by the ported core (the old "response model uses
`reasoning_effort=low`" note above no longer applies to chat). If reintroduced, it must be a
per-model capability flag stripped from the fallback kwargs — the Mistral fallback models
likely don't support it (see integration brief §3).

## Amendment (2026-07-09) — STT: Whisper on Scaleway primary, Voxtral fallback

The original STT row (`voxtral-mini-latest` on direct Mistral) is superseded. Trigger:
Scaleway deprecated its hosted Voxtral (`voxtral-small-24b`, EOL 2026-08-01), forcing the
provider question — and the answer follows the data, not the model. Raw voice recordings
are the app's most sensitive payload (Art. 9 content in an identifiable voice). Scaleway
Generative APIs are zero-retention Paris inference outside the US CLOUD Act; Mistral
La Plateforme retains inputs up to 30 days for abuse monitoring until ZDR is granted, with
some non-EU subprocessors under SCCs. So the microphone path stays in
the Scaleway-only chain, and Mistral serves only as availability fallback — the same
topology as the chat agents:

| Role | Primary (Scaleway) | Fallback (direct Mistral) |
|---|---|---|
| STT (dream voice journaling) | `openai/whisper-large-v3:fp16` | `voxtral-mini-2602` (Transcribe V2) |

Both providers implement the OpenAI-compatible `POST /v1/audio/transcriptions` multipart
shape (`redream_ai/audio/stt.py`). The fallback is now **pinned** (`voxtral-mini-2602`),
closing the original "STT intentionally uses `-latest`" exception. Quality: Voxtral V2
benchmarks slightly better on multilingual WER; whisper-large-v3 is proven for EN/DE and
the compliance edge wins. Env: `WHISPER_STT_MODEL` + `VOXTRAL_STT_MODEL`.

TTS is unchanged (`voxtral-mini-tts-2603`, direct Mistral) — Scaleway offers no TTS at
all, and TTS input is rewritten dream text (already in the Mistral fallback chain), not
the user's voice.

## Amendment (2026-10-01) — TTS implemented with a preset voice

`audio/tts.py` is no longer a stub. Verified live on 2026-10-01:

- Voxtral TTS rejects requests without `voice_id` or `ref_audio`. Mistral now ships preset
  voices (`GET /v1/audio/voices`: English and French, no German), and their slug works as
  `voice_id`. Both languages default to `gb_jane_neutral`; German text through it
  transcribed back word for word with `voxtral-mini-2602`. A cloned or commissioned voice
  replaces it by setting `VOXTRAL_VOICE_ID_EN/DE`.
- Request shape: `POST https://api.mistral.ai/v1/audio/speech`
  `{model, input, voice_id, response_format: "mp3"}` → `{audio_data: <base64>}`.
- Audio goes to the private `rehearsal-audio` bucket (migration `20261001000001`) under
  `users/{user_id}/{dream_id}/{lang}-{hash}.mp3`; the hash makes unchanged dreams a cache
  hit, and the per-user prefix is what the GDPR purge deletes. The app receives a signed
  URL on `SUPABASE_PUBLIC_URL` (default lifetime one year, `REHEARSAL_URL_TTL_SECONDS`).
- Privacy: there is still no Scaleway TTS, so rewritten dream text reaches Mistral
  directly (30-day abuse-monitoring retention until ZDR). The consent
  text names Mistral for AI responses and rehearsal audio since consent version
  `2026-10-03`.

