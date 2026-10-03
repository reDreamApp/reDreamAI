"""POST /audio/transcribe — dream voice journaling (ADR 0010).

Proxies the AI service's STT (Whisper-on-Scaleway primary, Voxtral fallback).
The transcript is returned to the client for the composer — nothing is
persisted here, and the audio bytes are discarded by both services.

Transcription tokens count against the same 100k/day budget as chat
(ADR 0008): budget is checked before forwarding and the AI-reported usage is
recorded after.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.dependencies import get_current_user, get_db, require_consent
from ....db.models.user import User
from ....services.ai_client import AIServiceError, BaseAiClient, get_ai_client
from ....services.token_budget import check_budget, record_usage
from .schemas import TranscribeOut

log = logging.getLogger(__name__)

router = APIRouter(prefix="/audio", tags=["audio"])

# A dream narration is a few minutes of speech; 25 MB (the common Whisper
# service cap) is generous for that and bounds memory per request.
MAX_AUDIO_BYTES = 25 * 1024 * 1024


@router.post(
    "/transcribe",
    response_model=TranscribeOut,
    dependencies=[Depends(require_consent)],
)
async def transcribe(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    ai: BaseAiClient = Depends(get_ai_client),
) -> TranscribeOut:
    if not file.filename:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "filename required")

    over, retry_after = await check_budget(db, user_id=user.id)
    if over:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"daily token budget exceeded — resets in {retry_after}s",
            headers={"Retry-After": str(retry_after)},
        )

    audio_bytes = await file.read()
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status.HTTP_413_CONTENT_TOO_LARGE,
            f"audio exceeds {MAX_AUDIO_BYTES // (1024 * 1024)} MB",
        )

    try:
        result = await ai.transcribe(file_name=file.filename, audio_bytes=audio_bytes)
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"transcribe: {exc}") from exc

    await record_usage(
        db,
        user_id=user.id,
        input_tokens=int(result.get("input_tokens", 0) or 0),
        output_tokens=int(result.get("output_tokens", 0) or 0),
    )

    return TranscribeOut(
        text=str(result.get("text", "")),
        language_detected=result.get("language_detected"),
    )
