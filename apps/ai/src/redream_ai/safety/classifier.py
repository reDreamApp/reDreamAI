"""Crisis-detection pre-classifier (ADR 0005)."""

from __future__ import annotations

import json
from typing import Any

from ..llm.base import LlmClient
from ..models import Language, SafetyCategory, SafetyResponse, SafetyRisk
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
) -> SafetyResponse:
    """Run the safety classifier over user-supplied text.

    The classifier is prompted to err on false positives — see ADR 0005.
    """

    system_prompt = _PROMPT_BY_LANG[language]
    messages: list[dict[str, Any]] = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text},
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
