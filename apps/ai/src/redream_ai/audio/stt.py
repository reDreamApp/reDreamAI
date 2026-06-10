"""Voxtral STT — transcribe dream voice journals (ADR 0010 phase 1).

Storage policy: the source audio is NOT persisted. Transcribe, return text,
discard bytes. If users later want playback of their own narration, that's a
deliberate scope expansion.
"""

from __future__ import annotations

from ..models import TranscribeResponse


async def transcribe(*, audio_bytes: bytes, file_name: str) -> TranscribeResponse:
    """Transcribe `audio_bytes` via Voxtral STT.

    Not yet implemented. Pending Mistral SDK audio client integration —
    `client.audio.transcriptions.complete(model=..., file={"content": f, "file_name": ...})`.
    """
    raise NotImplementedError("STT not yet wired to Mistral SDK.")
