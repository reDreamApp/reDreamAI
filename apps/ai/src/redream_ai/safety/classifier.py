"""Crisis-detection pre-classifier (ADR 0005)."""

from __future__ import annotations

import json
from typing import Any

from ..llm.base import LlmClient
from ..models import Language, SafetyCategory, SafetyResponse, SafetyRisk, Stage
from ..prompts.safety import PROMPT_VERSION, SAFETY_PROMPT_DE, SAFETY_PROMPT_EN

_PROMPT_BY_LANG: dict[Language, str] = {
    Language.EN: SAFETY_PROMPT_EN,
    Language.DE: SAFETY_PROMPT_DE,
}

_RESPONSE_FORMAT: dict[str, Any] = {"type": "json_object"}


async def classify(
    *,
    llm: LlmClient,
    model: str,
    text: str,
    language: Language,
    stage: Stage | None = None,
    context: str | None = None,
) -> SafetyResponse:
    """Run the safety classifier over user-supplied text.

    The classifier is prompted to err on false positives — see ADR 0005.
    `stage` and `context` (the assistant message being answered) disambiguate
    terse replies: "It is an 8 out of 10." is a scale answer, not ideation.
    """

    system_prompt = _PROMPT_BY_LANG[language]
    parts: list[str] = []
    if stage is not None:
        parts.append(f"[IRT stage: {stage.value}]")
    if context:
        parts.append(f"[Assistant message being replied to]\n{context}")
    parts.append(f"[User message to classify]\n{text}" if parts else text)
    messages: list[dict[str, Any]] = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "\n\n".join(parts)},
    ]

    content, _usage = await llm.chat(
        model=model,
        messages=messages,
        temperature=0.0,
        response_format=_RESPONSE_FORMAT,
    )

    parsed = json.loads(content)
    return SafetyResponse(
        risk=SafetyRisk(parsed["risk"]),
        categories=[SafetyCategory(c) for c in parsed.get("categories", [])],
        confidence=float(parsed.get("confidence", 0.0)),
        prompt_version=PROMPT_VERSION,
    )
