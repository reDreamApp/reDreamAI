"""Client for the AI service (apps/ai).

Routes depend on the `BaseAiClient` protocol so tests can substitute a fake
(see tests/conftest.py). Endpoints:

- POST /chat              : full conversation history → next stage + response
- POST /safety/classify   : user text → risk classification (ADR 0005)
- POST /audio/transcribe  : multipart audio → transcript (ADR 0010)
- POST /rehearsal/generate: dream → audio_url + script + duration
"""

from __future__ import annotations

from typing import Annotated, Any, Protocol

import httpx
from fastapi import Depends

from ..core.config import settings


class AIServiceError(Exception):
    """The AI service returned a non-2xx response or was unreachable."""


class BaseAiClient(Protocol):
    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]: ...
    async def safety_classify(self, payload: dict[str, Any]) -> dict[str, Any]: ...
    async def transcribe(self, *, file_name: str, audio_bytes: bytes) -> dict[str, Any]: ...
    async def rehearsal_generate(self, payload: dict[str, Any]) -> dict[str, Any]: ...


class HttpxAiClient:
    """Production `BaseAiClient`."""

    def __init__(self, *, base_url: str | None = None, timeout: float | None = None) -> None:
        self._base_url = (base_url or settings.ai_service_url).rstrip("/")
        self._timeout = timeout or settings.ai_request_timeout

    async def _post(self, path: str, **kwargs: Any) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                r = await client.post(f"{self._base_url}{path}", **kwargs)
        except httpx.HTTPError as exc:
            raise AIServiceError(f"{path} unreachable: {exc}") from exc
        if r.status_code >= 300:
            raise AIServiceError(f"{path} failed: {r.status_code} {r.text[:200]}")
        data: dict[str, Any] = r.json()
        return data

    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._post("/chat", json=payload)

    async def safety_classify(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._post("/safety/classify", json=payload)

    async def transcribe(self, *, file_name: str, audio_bytes: bytes) -> dict[str, Any]:
        return await self._post(
            "/audio/transcribe",
            files={"file": (file_name, audio_bytes, "application/octet-stream")},
        )

    async def rehearsal_generate(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._post("/rehearsal/generate", json=payload)


_default_client: BaseAiClient | None = None


def get_ai_client() -> BaseAiClient:
    """FastAPI dependency. Returns the process-wide AI client."""
    global _default_client
    if _default_client is None:
        _default_client = HttpxAiClient()
    return _default_client


Ai = Annotated[BaseAiClient, Depends(get_ai_client)]
