"""Voxtral TTS + STT through the Mistral SDK (ADR 0010)."""

from __future__ import annotations

import base64
from typing import Any

from ..llm.mistral_client import make_client


class MistralAudioClient:
    """Implements `Synthesizer` and `Transcriber`."""

    def __init__(self, api_key: str) -> None:
        # Synthesizing a full rehearsal script takes longer than a chat call.
        self._client = make_client(api_key, timeout_ms=60_000)

    async def synthesize(self, *, text: str, model: str, voice_id: str | None) -> bytes:
        kwargs: dict[str, Any] = {"input": text, "model": model, "response_format": "mp3"}
        if voice_id:
            kwargs["voice_id"] = voice_id
        response = await self._client.audio.speech.complete_async(**kwargs)
        audio = getattr(response, "audio_data", None)
        if not isinstance(audio, str):
            raise RuntimeError("Voxtral TTS returned no audio_data")
        return base64.b64decode(audio)

    async def transcribe(
        self, *, audio: bytes, file_name: str, model: str
    ) -> tuple[str, str | None, dict[str, int]]:
        response = await self._client.audio.transcriptions.complete_async(
            model=model, file={"content": audio, "file_name": file_name}
        )
        usage = getattr(response, "usage", None)
        return (
            response.text or "",
            getattr(response, "language", None),
            {
                "input_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
                "output_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
            },
        )
