"""POST /audio/transcribe + POST /rehearsal/generate (ADR 0010)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from ..audio import stt, tts
from ..models import RehearsalRequest, RehearsalResponse, TranscribeResponse

router = APIRouter()


@router.post("/audio/transcribe", response_model=TranscribeResponse)
async def audio_transcribe(
    file: Annotated[UploadFile, File()],
) -> TranscribeResponse:
    if file.filename is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "filename required")
    return await stt.transcribe(audio_bytes=await file.read(), file_name=file.filename)


@router.post("/rehearsal/generate", response_model=RehearsalResponse)
async def rehearsal_generate(req: RehearsalRequest) -> RehearsalResponse:
    if not req.rewritten_dream.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "rewritten_dream must not be empty")
    return await tts.generate_rehearsal(req)
