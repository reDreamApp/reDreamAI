# 0003 — Structured outputs for routing and summary

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Legacy backend has `_parse_summary` in `backend/.../chats/routes.py:67-124`: a string-matching parser scanning LLM output for headings like `"dream summary"`, `"traumzusammenfassung"`, `"Are you satisfied…"`. This works because the legacy prompts happen to produce those exact headings. The moment the LLM phrases summaries differently (Groq → Mistral Small 4), dream auto-creation silently breaks. Similarly the routing agent's "single word stage name" is parsed by free-text matching — fragile.

## Decision
Use Mistral's structured outputs (JSON mode + schema) on the AI service for two endpoints:

1. **Routing agent** — returns `{"stage": "recording"|"intensity"|"rewriting"|"summary"|"final", "confidence": float}`.
2. **Summary stage of `POST /chat`** — when `stage == "summary"`, response includes `structured: {title, original_summary, rewritten_summary, dream_summary}`.

Backend reads these fields directly and stores them into `dreams` columns. No string matching.

## Consequences

### Positive
- Model swaps don't silently break parsing.
- Summary fields are typed at the contract layer, not inferred.
- Routing JSON makes A/B-ing routing models trivial (Ministral 8B vs 14B).

### Negative
- Streaming chat (ADR 0009) for the summary stage is harder — must accumulate JSON until valid before emitting. For non-summary stages, plain text streaming is fine.
- Schema changes become a versioned contract (see `docs/contracts.md` once written).

## Alternatives considered
- **Keep `_parse_summary`, port verbatim**: rejected; flagged as one of the legacy pitfalls.
- **Function calling / tool use** instead of `response_format`: equivalent in shape, but JSON mode is simpler for non-tool semantics.
