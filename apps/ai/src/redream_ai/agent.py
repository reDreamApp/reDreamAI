"""IRT chat agent: routing + response (ADR 0002 stateless, ADR 0003 structured).

Two LLM passes per turn:

1. `route()` — the routing agent classifies which IRT stage should follow
   (structured JSON, like the safety classifier). The raw proposal is always
   passed through `irt.enforce_transition`, so a hallucinated or illegal stage
   falls back to a legal one.
2. `respond()` — the response agent generates the assistant's reply using the
   per-stage system prompt from `prompts/{en,de}.py`. The SUMMARY stage uses
   JSON mode + schema (ADR 0003) so the backend can persist a Dream from the
   structured fields without any `_parse_summary` string-matching.

This module is the only orchestration point; `api/chat.py` just wires it to the
request/response models and the DI'd `LlmClient`.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from . import irt as irt_mod
from . import observability as obs
from .llm.base import LlmClient
from .models import ChatRequest, Language, Stage, SummaryStructured
from .prompts import de as de_prompts
from .prompts import en as en_prompts
from .prompts import routing as routing_prompts

log = logging.getLogger(__name__)

_JSON_OBJECT: dict[str, Any] = {"type": "json_object"}

# Per-language prompt banks: (system-prompts-by-stage, prompt-version).
_PROMPTS_BY_LANG: dict[Language, tuple[dict[Stage, str], str]] = {
    Language.EN: (en_prompts.SYSTEM_PROMPTS, en_prompts.PROMPT_VERSION),
    Language.DE: (de_prompts.SYSTEM_PROMPTS, de_prompts.PROMPT_VERSION),
}

# Closing labels for the rendered SUMMARY message (the structured fields are the
# source of truth; this rendering is only what the user reads in the chat).
_SUMMARY_RENDER: dict[Language, dict[str, str]] = {
    Language.EN: {
        "title": "Title",
        "rewritten": "Rewritten Dream",
        "original": "Original Dream",
        "closing": "Are you satisfied with the generated summary?",
    },
    Language.DE: {
        "title": "Titel",
        "rewritten": "Umgeschriebener Traum",
        "original": "Ursprünglicher Traum",
        "closing": "Bist du mit der generierten Zusammenfassung zufrieden?",
    },
}

# Appended to the verbatim SUMMARY prompt to switch its output channel to JSON
# (ADR 0003). The clinical rules in the prompt body still apply to each field;
# only the *delivery format* changes from the prose "Title:/.../..." block.
_SUMMARY_JSON_INSTRUCTION = (
    "\n\nReturn ONLY a JSON object — no prose, no markdown fences — with exactly "
    "these keys:\n"
    '  "title": a short title for the dream,\n'
    '  "rewritten_summary": the summary of the rewritten dream, following every '
    "rule above (100% independent, only positive description, no comparison),\n"
    '  "original_summary": the summary of the original dream with its sensory '
    "details,\n"
    '  "intensity": the 0-10 distress rating the user gave for the original '
    "nightmare earlier in the conversation, as a JSON number — or null if they "
    "never gave one. Copy the user's rating exactly; do not estimate it yourself."
)


def _coerce_intensity(raw: object) -> int | None:
    """Lenient 0-10 coercion — a sloppy LLM value must not sink the summary."""
    try:
        value = int(float(str(raw)))
    except (TypeError, ValueError):
        return None
    return value if 0 <= value <= 10 else None


def _history_messages(req: ChatRequest) -> list[dict[str, str]]:
    """Conversation history mapped to provider chat messages (no system prompt)."""
    return [{"role": m.role.value, "content": m.content} for m in req.messages]


async def route(
    *, llm: LlmClient, model: str, req: ChatRequest, trace: obs.Trace = None
) -> tuple[Stage, dict[str, int]]:
    """Routing agent: propose the next IRT stage (pre-enforcement).

    Returns (proposed_stage, usage). Falls back to the current stage if the
    model returns an unparseable or unknown stage. Records the call as a
    Langfuse generation under `trace` (no-op when tracing is disabled).
    """

    current = irt_mod.current_stage(req.messages)
    messages: list[dict[str, Any]] = [
        {
            "role": "system",
            "content": (
                f"{routing_prompts.ROUTING_PROMPT}\n"
                f"The current stage is: {current.value}."
            ),
        },
        *_history_messages(req),
    ]
    content, usage = await llm.chat(
        model=model,
        messages=messages,
        temperature=0.0,
        response_format=_JSON_OBJECT,
    )
    obs.record_generation(
        trace,
        name="irt-route",
        model=model,
        input=messages,
        output=content,
        usage=usage,
        metadata={"prompt_version": routing_prompts.PROMPT_VERSION, "current_stage": current.value},
    )
    try:
        proposed = Stage(json.loads(content)["stage"])
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        log.warning("routing agent returned unusable stage (%s); staying at %s", exc, current)
        proposed = current
    return proposed, usage


def _render_summary(structured: SummaryStructured, language: Language) -> str:
    labels = _SUMMARY_RENDER[language]
    return (
        f"{labels['title']}: {structured.title}\n\n"
        f"{labels['rewritten']}: {structured.rewritten_summary}\n\n"
        f"{labels['original']}: {structured.original_summary}\n\n"
        f"{labels['closing']}"
    )


async def respond(
    *,
    llm: LlmClient,
    model: str,
    stage: Stage,
    req: ChatRequest,
    trace: obs.Trace = None,
) -> tuple[str, SummaryStructured | None, dict[str, int], str]:
    """Response agent: generate the assistant reply for the (enforced) stage.

    Returns (response_text, structured, usage, prompt_version). `structured` is
    populated only for the SUMMARY stage (ADR 0003). Each LLM call is recorded
    as a Langfuse generation under `trace` (no-op when tracing is disabled).
    """

    system_prompts, prompt_version = _PROMPTS_BY_LANG[req.language]
    system = system_prompts[stage]

    if stage == Stage.SUMMARY:
        messages: list[dict[str, Any]] = [
            {"role": "system", "content": system + _SUMMARY_JSON_INSTRUCTION},
            *_history_messages(req),
        ]
        usage = {"input_tokens": 0, "output_tokens": 0}
        content = ""
        # Without `structured` the backend cannot persist a Dream at all, so a
        # malformed JSON response is worth one re-roll before giving up.
        for attempt in range(2):
            content, call_usage = await llm.chat(
                model=model,
                messages=messages,
                temperature=0.4,
                response_format=_JSON_OBJECT,
            )
            obs.record_generation(
                trace,
                name=f"irt-respond-summary-{attempt + 1}",
                model=model,
                input=messages,
                output=content,
                usage=call_usage,
                metadata={"stage": stage.value, "prompt_version": prompt_version},
            )
            usage = {
                "input_tokens": usage["input_tokens"] + call_usage.get("input_tokens", 0),
                "output_tokens": usage["output_tokens"] + call_usage.get("output_tokens", 0),
            }
            try:
                parsed = json.loads(content)
                original = str(parsed["original_summary"])
                structured = SummaryStructured(
                    title=str(parsed["title"]),
                    rewritten_summary=str(parsed["rewritten_summary"]),
                    original_summary=original,
                    # Backend reads `dream_summary` first for the original_dream
                    # column; mirror it so either key resolves correctly.
                    dream_summary=original,
                    intensity=_coerce_intensity(parsed.get("intensity")),
                )
            except (json.JSONDecodeError, KeyError) as exc:
                log.warning(
                    "summary agent returned unparseable JSON (attempt %d: %s)",
                    attempt + 1,
                    exc,
                )
                continue
            return _render_summary(structured, req.language), structured, usage, prompt_version
        log.warning("summary agent failed twice; passing raw text without structured fields")
        return content, None, usage, prompt_version

    messages = [
        {"role": "system", "content": system},
        *_history_messages(req),
    ]
    content, usage = await llm.chat(model=model, messages=messages, temperature=0.5)
    obs.record_generation(
        trace,
        name="irt-respond",
        model=model,
        input=messages,
        output=content,
        usage=usage,
        metadata={"stage": stage.value, "prompt_version": prompt_version},
    )
    return content, None, usage, prompt_version
