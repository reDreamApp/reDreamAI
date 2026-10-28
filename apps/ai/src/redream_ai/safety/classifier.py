"""Crisis-detection pre-classifier (ADR 0005)."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from .. import observability as obs
from ..llm.base import LlmClient
from ..models import Language, SafetyCategory, SafetyResponse, SafetyRisk, Stage
from ..prompts.safety import (
    PROMPT_VERSION,
    SAFETY_PROMPT_DE,
    SAFETY_PROMPT_EN,
    SAFETY_PROMPT_FALLBACK_DE,
    SAFETY_PROMPT_FALLBACK_EN,
)

log = logging.getLogger(__name__)

_PROMPT_BY_LANG: dict[Language, str] = {
    Language.EN: SAFETY_PROMPT_EN,
    Language.DE: SAFETY_PROMPT_DE,
}
# The fallback model misses real farewells with the revenge rule (v0.5.1).
_FALLBACK_PROMPT_BY_LANG: dict[Language, str] = {
    Language.EN: SAFETY_PROMPT_FALLBACK_EN,
    Language.DE: SAFETY_PROMPT_FALLBACK_DE,
}

_RESPONSE_FORMAT: dict[str, Any] = {"type": "json_object"}

# A reply made only of these words agrees or disagrees and carries no risk of
# its own; the danger named in the question it answers is the guide's
# wording, not the user's. The model still flagged some of them ("Hat er dich
# gewürgt?" → "ja" came back high), so they skip it (v0.4.1).
_BARE_ANSWER_WORDS = frozenset(
    {
        # English
        "yes", "yeah", "yep", "yup", "no", "nope", "nah", "ok", "okay", "sure",
        "exactly", "right", "correct", "true", "maybe", "mhm",
        # German
        "ja", "jo", "jep", "jap", "nein", "ne", "nö", "genau", "stimmt",
        "richtig", "klar", "vielleicht", "doch",
    }
)  # fmt: skip
_MAX_BARE_ANSWER_WORDS = 3

# In these stages every assistant message is about the user's dream, even
# when it does not say "dream".
_DREAM_STAGES = frozenset({Stage.RECORDING, Stage.REWRITING, Stage.SUMMARY})
_GREETING_CONTEXT = (
    "[Assistant message being replied to (the app's greeting)]\n"
    "Tell me about a dream that troubles you."
)


def _is_bare_answer(text: str) -> bool:
    if any(ch.isdigit() for ch in text):
        return False  # a rating is the model's call (scale answers)
    words = re.findall(r"[^\W\d_]+", text.lower())
    return 0 < len(words) <= _MAX_BARE_ANSWER_WORDS and all(w in _BARE_ANSWER_WORDS for w in words)


async def classify(
    *,
    llm: LlmClient,
    model: str,
    text: str,
    language: Language,
    stage: Stage | None = None,
    context: str | None = None,
    trace: obs.Trace = None,
    fallback_llm: LlmClient | None = None,
    fallback_model: str | None = None,
) -> SafetyResponse:
    """Run the safety classifier over user-supplied text.

    The classifier is prompted to err on false positives — see ADR 0005.
    `stage` and `context` (the assistant message being answered) disambiguate
    terse replies: "It is an 8 out of 10." is a scale answer, not ideation.
    A bare yes / no needs no model call (`_is_bare_answer`).

    Any failure of the primary model, an unusable answer included, goes to
    `fallback_model` on `fallback_llm` when one is given: the backend blocks
    the chat turn when this check fails.
    """

    if _is_bare_answer(text):
        return SafetyResponse(
            risk=SafetyRisk.NONE, categories=[], confidence=1.0, prompt_version=PROMPT_VERSION
        )

    parts: list[str] = []
    if stage is not None:
        parts.append(f"[IRT stage: {stage.value}]")
    if context:
        about = " (about the user's dream)" if stage in _DREAM_STAGES else ""
        parts.append(f"[Assistant message being replied to{about}]\n{context}")
    elif stage is Stage.RECORDING:
        # The chat's first message answers the app's greeting, which is not
        # in the history: without it, nightmares told in the present tense
        # read as real events (2026-10-27 simulated users, v0.5.0).
        parts.append(_GREETING_CONTEXT)
    parts.append(f"[User message to classify]\n{text}" if parts else text)
    user_content = "\n\n".join(parts)

    try:
        return await _ask(llm, model, _messages(_PROMPT_BY_LANG[language], user_content), trace)
    except Exception as exc:
        if fallback_llm is None or fallback_model is None:
            raise
        log.warning(
            "safety.primary_failed model=%s error=%s — falling back to %s",
            model,
            exc,
            fallback_model,
        )
        fallback_messages = _messages(_FALLBACK_PROMPT_BY_LANG[language], user_content)
        return await _ask(fallback_llm, fallback_model, fallback_messages, trace)


def _messages(system_prompt: str, user_content: str) -> list[dict[str, Any]]:
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_content},
    ]


async def _ask(
    llm: LlmClient, model: str, messages: list[dict[str, Any]], trace: obs.Trace
) -> SafetyResponse:
    content, usage = await llm.chat(
        model=model,
        messages=messages,
        temperature=0.0,
        response_format=_RESPONSE_FORMAT,
    )
    obs.record_generation(
        trace,
        name="safety-classify",
        model=model,
        input=messages,
        output=content,
        usage=usage,
        metadata={"prompt_version": PROMPT_VERSION},
    )

    parsed = json.loads(content)
    return SafetyResponse(
        risk=SafetyRisk(parsed["risk"]),
        categories=[SafetyCategory(c) for c in parsed.get("categories", [])],
        confidence=float(parsed.get("confidence", 0.0)),
        prompt_version=PROMPT_VERSION,
    )
