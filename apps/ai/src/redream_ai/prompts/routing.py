"""Routing agent prompt (ADR 0003 — structured output).

The routing agent emits JSON: `{"stage": "<stage>", "confidence": <0..1>}`.
The stage value is validated and constrained by `redream_ai.irt.enforce_transition`
before being used — so even a hallucinated stage name falls back to a legal one.
"""

PROMPT_VERSION = "routing-v0.1.0"

ROUTING_PROMPT = """\
You are a stage classifier for an imagery rehearsal therapy chatbot.

Given the conversation so far and the user's latest message, decide which
stage of the IRT process should follow. The five stages are:

- recording: user is describing a nightmare
- intensity: user is rating distress on a 0-10 scale
- rewriting: user is reshaping the nightmare into a more empowering narrative
- summary: synthesizing the original + rewritten dreams
- final: closing the session

Reply with JSON only:
{"stage": "<stage>", "confidence": <0.0-1.0>}
"""
