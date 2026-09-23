"""POST /chat — IRT routing + response (ADR 0002 stateless, ADR 0009 streaming).

Stage transitions are enforced by `redream_ai.irt`. The response-agent prompt
port and the streaming SSE variant are still TODO; this non-streaming route
returns an empty response with the correct stage so the contract is
exercisable end-to-end before the prompt port lands.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from .. import irt
from ..models import ChatRequest, ChatResponse, UsageStats

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    if not req.messages:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "messages must not be empty")

    stage = irt.enforce_transition(req.messages, irt.current_stage(req.messages))

    # TODO: routing agent + response agent.
    return ChatResponse(
        stage=stage,
        response="",
        structured=None,
        usage=UsageStats(input_tokens=0, output_tokens=0),
        prompt_version="chat-v0.0.0-stub",
    )
