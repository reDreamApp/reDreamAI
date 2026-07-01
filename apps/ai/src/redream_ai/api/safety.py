"""POST /safety/classify — crisis pre-classifier (ADR 0005).

Backend must call this BEFORE every /chat turn. High-risk responses short-circuit
the IRT machine and trigger a helpline overlay client-side.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from .. import observability as obs
from ..config import settings
from ..llm.base import LlmClient
from ..models import SafetyRequest, SafetyResponse
from ..safety import classify
from .chat import get_llm_client

router = APIRouter()


@router.post("/safety/classify", response_model=SafetyResponse)
async def safety_classify(
    req: SafetyRequest,
    llm: LlmClient = Depends(get_llm_client),
) -> SafetyResponse:
    if not req.text.strip():
        raise HTTPException(400, "text must not be empty")

    # SafetyRequest carries no session_id (not part of the contract), so these
    # traces aren't session-grouped — they're still searchable by name/tag.
    trace = obs.start_trace(
        "safety-classify",
        input={"text": req.text, "stage": req.stage.value if req.stage else None},
        metadata={"language": req.language.value},
    )
    result = await classify(
        llm=llm,
        model=settings.mistral_safety_model,
        text=req.text,
        language=req.language,
        stage=req.stage,
        context=req.context,
        trace=trace,
    )
    obs.update_trace(
        trace,
        output={
            "risk": result.risk.value,
            "categories": [c.value for c in result.categories],
            "confidence": result.confidence,
        },
    )
    return result
