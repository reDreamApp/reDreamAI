"""POST /audio/transcribe + POST /rehearsal/generate (ADR 0010)."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile

from ..audio import stt, tts
from ..models import RehearsalRequest, RehearsalResponse, TranscribeResponse
from ..request_limits import MAX_AUDIO_BYTES

router = APIRouter()


@router.post("/audio/transcribe", response_model=TranscribeResponse)
async def audio_transcribe(file: UploadFile = File(...)) -> TranscribeResponse:
    if file.filename is None:
        raise HTTPException(400, "filename required")
    audio_bytes = await file.read(MAX_AUDIO_BYTES + 1)
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(413, "audio exceeds 25 MB")
    return await stt.transcribe(audio_bytes=audio_bytes, file_name=file.filename)


@router.post("/rehearsal/generate", response_model=RehearsalResponse)
async def rehearsal_generate(req: RehearsalRequest) -> RehearsalResponse:
    if not req.rewritten_dream.strip():
        raise HTTPException(400, "rewritten_dream must not be empty")
    return await tts.generate_rehearsal(req)
