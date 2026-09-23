"""POST /safety/classify — crisis pre-classifier (ADR 0005).

The backend calls this BEFORE every /chat turn; a high-risk result
short-circuits the IRT machine and triggers a helpline overlay client-side.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..models import SafetyRequest, SafetyResponse
from ..safety import classify
from .deps import Llm

router = APIRouter()


@router.post("/safety/classify", response_model=SafetyResponse)
async def safety_classify(req: SafetyRequest, llm: Llm) -> SafetyResponse:
    if not req.text.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "text must not be empty")
    return await classify(
        llm=llm,
        model=settings.mistral_safety_model,
        text=req.text,
        language=req.language,
    )
