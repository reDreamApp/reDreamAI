"""POST /chat — IRT routing + response (ADR 0002 stateless, ADR 0003 structured).

Per turn:
  1. Routing agent proposes the next stage (`agent.route`).
  2. `irt.enforce_transition` constrains the proposal to a legal stage.
  3. Response agent generates the reply for that stage (`agent.respond`); the
     SUMMARY stage additionally returns structured fields for the backend to
     persist a Dream (no `_parse_summary` — ADR 0003).

The streaming SSE variant (ADR 0009) is still TODO; this is the non-streaming
route the backend currently calls.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from .. import agent
from .. import irt as irt_mod
from ..config import settings
from ..llm.base import LlmClient
from ..models import ChatRequest, ChatResponse, UsageStats

router = APIRouter()


async def get_llm_client() -> LlmClient:
    """DI hook. Overridden in `main.py` (prod) and in tests (FakeLlmClient)."""
    raise NotImplementedError(
        "LlmClient dependency must be configured by the app factory in main.py."
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    req: ChatRequest,
    llm: LlmClient = Depends(get_llm_client),
) -> ChatResponse:
    """Non-streaming /chat (streaming variant per ADR 0009 — TODO)."""

    if not req.messages:
        raise HTTPException(400, "messages must not be empty")

    proposed, route_usage = await agent.route(
        llm=llm, model=settings.mistral_routing_model, req=req
    )
    stage = irt_mod.enforce_transition(req.messages, proposed)

    response_text, structured, resp_usage, prompt_version = await agent.respond(
        llm=llm, model=settings.mistral_response_model, stage=stage, req=req
    )

    usage = UsageStats(
        input_tokens=route_usage.get("input_tokens", 0) + resp_usage.get("input_tokens", 0),
        output_tokens=route_usage.get("output_tokens", 0) + resp_usage.get("output_tokens", 0),
    )
    return ChatResponse(
        stage=stage,
        response=response_text,
        structured=structured,
        usage=usage,
        prompt_version=prompt_version,
    )
