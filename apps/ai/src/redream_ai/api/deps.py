"""Shared FastAPI dependencies for the AI service."""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from fastapi import Depends, HTTPException, status

from ..audio.base import AudioStorage, Synthesizer, Transcriber
from ..config import settings
from ..llm.base import LlmClient


def _require_mistral() -> None:
    if not settings.mistral_api_key:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "LLM not configured (set MISTRAL_API_KEY)"
        )


@lru_cache(maxsize=1)
def _mistral_client() -> LlmClient:
    from ..llm.mistral_client import MistralLlmClient

    return MistralLlmClient(api_key=settings.mistral_api_key)


@lru_cache(maxsize=1)
def _mistral_audio() -> Synthesizer | Transcriber:
    from ..audio.mistral_audio import MistralAudioClient

    return MistralAudioClient(api_key=settings.mistral_api_key)


@lru_cache(maxsize=1)
def _supabase_storage() -> AudioStorage:
    from ..audio.supabase_storage import SupabaseAudioStorage

    return SupabaseAudioStorage(
        url=settings.supabase_url,
        service_role_key=settings.supabase_service_role_key,
        bucket=settings.supabase_storage_bucket,
        public_url=settings.supabase_public_url,
    )


def get_llm_client() -> LlmClient:
    """The process-wide LLM client. Overridden in tests with `FakeLlmClient`."""
    _require_mistral()
    return _mistral_client()


def get_synthesizer() -> Synthesizer:
    _require_mistral()
    return _mistral_audio()  # type: ignore[return-value]


def get_transcriber() -> Transcriber:
    _require_mistral()
    return _mistral_audio()  # type: ignore[return-value]


def get_audio_storage() -> AudioStorage:
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Storage not configured (set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY)",
        )
    return _supabase_storage()


Llm = Annotated[LlmClient, Depends(get_llm_client)]
Tts = Annotated[Synthesizer, Depends(get_synthesizer)]
Stt = Annotated[Transcriber, Depends(get_transcriber)]
Storage = Annotated[AudioStorage, Depends(get_audio_storage)]
