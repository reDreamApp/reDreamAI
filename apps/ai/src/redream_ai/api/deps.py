"""Shared FastAPI dependencies for the AI service."""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from fastapi import Depends, HTTPException, status

from ..config import settings
from ..llm.base import LlmClient


@lru_cache(maxsize=1)
def _mistral_client() -> LlmClient:
    from ..llm.mistral_client import MistralLlmClient

    return MistralLlmClient(api_key=settings.mistral_api_key)


def get_llm_client() -> LlmClient:
    """The process-wide LLM client. Overridden in tests with `FakeLlmClient`."""
    if not settings.mistral_api_key:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "LLM not configured (set MISTRAL_API_KEY)"
        )
    return _mistral_client()


Llm = Annotated[LlmClient, Depends(get_llm_client)]
