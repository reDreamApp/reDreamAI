"""Provider boundaries for the audio features (mirrors `llm.base`)."""

from __future__ import annotations

from typing import Protocol


class Synthesizer(Protocol):
    async def synthesize(self, *, text: str, model: str, voice_id: str | None) -> bytes:
        """Text to MP3 bytes."""
        ...


class Transcriber(Protocol):
    async def transcribe(
        self, *, audio: bytes, file_name: str, model: str
    ) -> tuple[str, str | None, dict[str, int]]:
        """Audio to (text, detected language, usage)."""
        ...


class AudioStorage(Protocol):
    async def exists(self, path: str) -> bool: ...

    async def upload(self, path: str, data: bytes, *, content_type: str) -> None: ...

    async def signed_url(self, path: str, *, expires_in: int) -> str: ...
