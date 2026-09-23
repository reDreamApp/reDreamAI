"""Voxtral STT — transcribe dream voice journals (ADR 0010 phase 1).

Storage policy: the source audio is NOT persisted. Transcribe, return text,
discard the bytes.
"""

from __future__ import annotations

from ..models import TranscribeResponse


async def transcribe(*, audio_bytes: bytes, file_name: str) -> TranscribeResponse:
    """Not yet implemented — pending the Mistral SDK audio client:
    `client.audio.transcriptions.complete(model=..., file={"content": f, "file_name": ...})`.
    """
    raise NotImplementedError("STT not yet wired to Mistral SDK.")
