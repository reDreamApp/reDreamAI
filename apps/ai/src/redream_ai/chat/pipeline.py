"""One IRT chat turn (ADR 0002 stateless, ADR 0003 structured outputs).

1. The routing agent proposes the next stage from the transcript.
2. `irt.enforce_transition` makes the proposal legal.
3. The response agent answers with that stage's system prompt. In the summary
   stage it answers in JSON, which is rendered to the user-facing text and
   returned as `structured` for the backend to persist.
"""

from __future__ import annotations

import json
import logging
from types import ModuleType
from typing import Any

from .. import irt
from ..llm.base import LlmClient
from ..models import (
    ChatRequest,
    ChatResponse,
    Language,
    Message,
    Role,
    Stage,
    SummaryStructured,
    UsageStats,
)
from ..prompts import de, en, routing

logger = logging.getLogger(__name__)

_PROMPTS: dict[Language, ModuleType] = {Language.EN: en, Language.DE: de}
_JSON: dict[str, Any] = {"type": "json_object"}


async def run_turn(
    *,
    llm: LlmClient,
    request: ChatRequest,
    routing_model: str,
    response_model: str,
) -> ChatResponse:
    history = request.messages
    prompts = _PROMPTS[request.language]

    stage, routing_usage = await _route(llm, routing_model, history)
    text, structured, usage = await _respond(llm, response_model, history, stage, prompts)

    return ChatResponse(
        stage=stage,
        response=text,
        structured=structured,
        usage=UsageStats(
            input_tokens=routing_usage.get("input_tokens", 0) + usage.get("input_tokens", 0),
            output_tokens=routing_usage.get("output_tokens", 0) + usage.get("output_tokens", 0),
        ),
        prompt_version=f"{prompts.PROMPT_VERSION}|{routing.PROMPT_VERSION}",
    )


async def _route(
    llm: LlmClient, model: str, history: list[Message]
) -> tuple[Stage, dict[str, int]]:
    current = irt.current_stage(history)
    visited = ", ".join(s.value for s in irt.STAGE_ORDER if s in irt.stages_visited(history))
    content = (
        f"Current stage: {current.value}\n"
        f"Stages visited so far: {visited or 'none'}\n\n"
        f"<transcript>\n{_transcript(history)}\n</transcript>"
    )
    text, usage = await llm.chat(
        model=model,
        messages=[
            {"role": "system", "content": routing.ROUTING_PROMPT},
            {"role": "user", "content": content},
        ],
        temperature=0.0,
        max_tokens=64,
        response_format=_JSON,
    )
    try:
        proposed = Stage(json.loads(text)["stage"])
    except (ValueError, KeyError, TypeError):
        logger.warning("routing agent returned no usable stage: %r", text)
        proposed = current
    return irt.enforce_transition(history, proposed), usage


async def _respond(
    llm: LlmClient,
    model: str,
    history: list[Message],
    stage: Stage,
    prompts: ModuleType,
) -> tuple[str, SummaryStructured | None, dict[str, int]]:
    system = (
        f"{prompts.SYSTEM_PROMPTS[stage]}\n\n"
        f"Your opening message to the user was:\n{prompts.INTRO_MESSAGE}"
    )
    if stage == Stage.SUMMARY:
        system = f"{system}\n\n{prompts.SUMMARY_JSON_INSTRUCTION}"
    else:
        system = f"{system}\n\n{prompts.PLAIN_TEXT_RULE}"

    messages: list[dict[str, Any]] = [
        {"role": "system", "content": system},
        *({"role": m.role.value, "content": m.content} for m in history),
    ]

    if stage != Stage.SUMMARY:
        text, usage = await llm.chat(
            model=model, messages=messages, temperature=0.5, max_tokens=1024
        )
        return text.strip(), None, usage

    text, usage = await llm.chat(
        model=model,
        messages=messages,
        temperature=0.3,
        max_tokens=1500,
        response_format=_JSON,
    )
    structured = _parse_summary(text, intensity=_intensity_rating(history))
    if structured is None:
        logger.warning("summary stage returned no usable JSON; passing text through")
        return text.strip(), None, usage
    rendered = prompts.SUMMARY_TEMPLATE.format(
        title=structured.title,
        rewritten=structured.rewritten_summary,
        original=structured.original_summary,
    )
    return rendered, structured, usage


def _parse_summary(text: str, *, intensity: int | None) -> SummaryStructured | None:
    try:
        data = json.loads(text)
        title = _as_text(data["title"])
        rewritten = _as_text(data.get("rewritten_dream") or data.get("rewritten_summary"))
        original = _as_text(data.get("original_dream") or data.get("original_summary"))
    except (ValueError, KeyError, TypeError, AttributeError):
        return None
    if not (title and rewritten and original):
        return None
    return SummaryStructured(
        title=title,
        original_summary=original,
        rewritten_summary=rewritten,
        dream_summary=original,
        intensity=intensity,
    )


def _as_text(value: object) -> str:
    """Models sometimes nest a field (`{"scene": "..."}`); keep only the prose."""
    if value is None:
        return ""
    if isinstance(value, dict):
        return "\n\n".join(filter(None, (_as_text(v) for v in value.values())))
    if isinstance(value, list):
        return "\n\n".join(filter(None, (_as_text(v) for v in value)))
    return str(value).strip()


def _intensity_rating(history: list[Message]) -> int | None:
    """The last 0-10 number the user typed while in the intensity stage."""
    rating: int | None = None
    stage = Stage.RECORDING
    for m in history:
        if m.role == Role.ASSISTANT and m.stage is not None:
            stage = m.stage
        elif m.role == Role.USER and stage == Stage.INTENSITY:
            try:
                value = int(m.content.strip())
            except ValueError:
                continue
            if 0 <= value <= 10:
                rating = value
    return rating


def _transcript(history: list[Message]) -> str:
    lines = []
    for m in history:
        if m.role == Role.ASSISTANT:
            label = f"Assistant [{m.stage.value}]" if m.stage else "Assistant"
        else:
            label = "User"
        lines.append(f"{label}: {m.content}")
    return "\n".join(lines)
