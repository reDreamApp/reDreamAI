"""POST /chat — IRT routing + response (ADR 0002 stateless, ADR 0003 structured).

Non-streaming; the SSE variant (ADR 0009) is still to come.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from ..chat import run_turn
from ..config import settings
from ..models import ChatRequest, ChatResponse
from .deps import Llm

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, llm: Llm) -> ChatResponse:
    if not req.messages:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "messages must not be empty")
    return await run_turn(
        llm=llm,
        request=req,
        routing_model=settings.mistral_routing_model,
        response_model=settings.mistral_response_model,
    )
