"""POST /chat — ported IRT chatbot core (recording → rewriting → summary → final).

Adapter over the ported orchestrator (`redream_ai.core.irt_app.process_chat_message`).
The AI service stays stateless (ADR 0002): the backend sends the full history each
turn, we rebuild a ported `Conversation` from it, run one turn, and map the result
back to the wire `ChatResponse`. The summary stage additionally runs a structured
extraction pass (ADR 0003). The neuro-symbolic `SafetyCritic` runs inside the ported
core during `rewriting` only.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException

from ..core import irt_app
from ..core.models import ChatInput as PortedChatInput
from ..core.models import Conversation as PortedConversation
from ..core.models import Message as PortedMessage
from ..models import ChatRequest, ChatResponse, Role, Stage, SummaryStructured, UsageStats
from ..summary_structured import extract_summary_structured

router = APIRouter()
log = logging.getLogger(__name__)

# The ported prompts carry no version constant; stamp the wire contract's required
# `prompt_version` with the ported prompt lineage so callers can pin behaviour.
PROMPT_VERSION = "irt-ported-2026-07"


async def get_llm_client():
    """DI hook for the crisis-classifier route (api/safety.py imports it).

    The /chat route no longer uses the LlmClient — it drives the ported core's own
    Scaleway/Mistral agents — but the crisis classifier (ADR 0005) still does.
    """
    raise NotImplementedError(
        "LlmClient dependency must be configured by the app factory in main.py."
    )


def _rebuild_conversation(req: ChatRequest) -> PortedConversation:
    """Rebuild the ported Conversation from the history BEFORE the new user message.

    The ported `process_chat_message` appends the new user message itself, so it must
    NOT already be in `conversation.messages`. `conversation.stages` is the resolved
    stage per prior turn — one per prior assistant message, in order.
    """
    history = req.messages[:-1]  # everything except the new user turn
    messages = [
        PortedMessage(
            content=m.content,
            role=m.role.value,
            stage=(m.stage.value if m.stage else None),
            language=(m.language.value if m.language else None),
        )
        for m in history
    ]
    stages = [m.stage.value for m in history if m.role == Role.ASSISTANT and m.stage is not None]
    return PortedConversation(
        session_id=req.session_id or "anonymous",
        messages=messages,
        stages=stages,
        language=req.language.value,
        nightmare_summary=req.nightmare_summary,
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    """Non-streaming /chat (SSE streaming variant per ADR 0009 — TODO)."""
    if not req.messages:
        raise HTTPException(400, "messages must not be empty")
    if irt_app.routing_agent is None or irt_app.response_agent is None:
        raise HTTPException(
            503, "IRT agents not configured (set SCALEWAY_API_KEY + MISTRAL_API_KEY)"
        )
    if req.messages[-1].role != Role.USER:
        raise HTTPException(400, "the last message must be the new user message")

    conversation = _rebuild_conversation(req)
    chat_input = PortedChatInput(
        session_id=conversation.session_id,
        message=req.messages[-1].content,
        language_override=req.language.value,
    )

    ported = await irt_app.process_chat_message(chat_input, conversation, safety_enabled=True)

    try:
        stage = Stage(ported.stage)
    except ValueError as exc:  # ported core should only emit recording/rewriting/summary/final
        log.error("ported core returned unmapped stage %r", ported.stage)
        raise HTTPException(500, f"internal stage mapping error: {ported.stage}") from exc

    structured: SummaryStructured | None = None
    if stage == Stage.SUMMARY:
        structured = await extract_summary_structured(ported.response, req.language)

    usage = UsageStats(
        input_tokens=(ported.usage or {}).get("input", 0),
        output_tokens=(ported.usage or {}).get("output", 0),
    )
    return ChatResponse(
        stage=stage,
        response=ported.response,
        structured=structured,
        usage=usage,
        prompt_version=PROMPT_VERSION,
        safety=ported.safety,
        # Echo the once-generated nightmare summary so the backend can persist it and
        # send it back next turn (ChatRequest.nightmare_summary) — avoids regenerating.
        nightmare_summary=conversation.nightmare_summary,
    )
