"""Voxtral STT — transcribe dream voice journals (ADR 0010 phase 1).

Storage policy: the source audio is NOT persisted. Transcribe, return text,
discard the bytes.
"""

from __future__ import annotations

from ..models import Language, TranscribeResponse
from .base import Transcriber


async def transcribe(
    *, transcriber: Transcriber, model: str, audio_bytes: bytes, file_name: str
) -> TranscribeResponse:
    text, language, usage = await transcriber.transcribe(
        audio=audio_bytes, file_name=file_name, model=model
    )
    return TranscribeResponse(
        text=text.strip(),
        language_detected=_language(language),
        input_tokens=usage.get("input_tokens", 0),
        output_tokens=usage.get("output_tokens", 0),
    )


def _language(code: str | None) -> Language | None:
    if not code:
        return None
    prefix = code.lower()[:2]
    return Language(prefix) if prefix in {"en", "de"} else None
