"""POST /audio/transcribe + POST /rehearsal/generate (ADR 0010)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from ..audio import stt, tts
from ..config import settings
from ..models import Language, RehearsalRequest, RehearsalResponse, TranscribeResponse
from .deps import Storage, Stt, Tts

router = APIRouter()


@router.post("/audio/transcribe", response_model=TranscribeResponse)
async def audio_transcribe(
    file: Annotated[UploadFile, File()], transcriber: Stt
) -> TranscribeResponse:
    if file.filename is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "filename required")
    return await stt.transcribe(
        transcriber=transcriber,
        model=settings.voxtral_stt_model,
        audio_bytes=await file.read(),
        file_name=file.filename,
    )


@router.post("/rehearsal/generate", response_model=RehearsalResponse)
async def rehearsal_generate(
    req: RehearsalRequest, synthesizer: Tts, storage: Storage
) -> RehearsalResponse:
    if not req.rewritten_dream.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "rewritten_dream must not be empty")
    return await tts.generate_rehearsal(
        req,
        synthesizer=synthesizer,
        storage=storage,
        model=settings.voxtral_tts_model,
        voice_ids={
            Language.EN: settings.voxtral_voice_id_en,
            Language.DE: settings.voxtral_voice_id_de,
        },
        url_ttl_seconds=settings.rehearsal_url_ttl_seconds,
    )
