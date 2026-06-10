"""POST /chat — IRT routing + response (ADR 0002 stateless, ADR 0009 streaming).

Skeleton: stage is enforced by `redream_ai.irt`. The response-agent prompt
port (`prompts/{en,de}.py`) and the streaming SSE variant are TODO; the
non-streaming route here returns an empty response with the correct stage,
so the route is exercisable end-to-end before the prompt port lands.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from .. import irt as irt_mod
from ..llm.base import LlmClient
from ..models import ChatRequest, ChatResponse, UsageStats

router = APIRouter()


async def get_llm_client() -> LlmClient:
    """DI hook. Overridden in `main.py` (prod) and in tests (FakeLlmClient)."""
    raise NotImplementedError(
        "LlmClient dependency must be configured by the app factory in main.py."
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    """Non-streaming /chat (streaming variant per ADR 0009 — TODO)."""

    if not req.messages:
        raise HTTPException(400, "messages must not be empty")

    current = irt_mod.current_stage(req.messages)
    next_stage = irt_mod.enforce_transition(req.messages, current)

    # TODO: routing agent + response agent.
    # Stub returns the enforced current stage with an empty response so the
    # contract is exercisable while prompts are being ported.
    return ChatResponse(
        stage=next_stage,
        response="",
        structured=None,
        usage=UsageStats(input_tokens=0, output_tokens=0),
        prompt_version="chat-v0.0.0-stub",
    )
