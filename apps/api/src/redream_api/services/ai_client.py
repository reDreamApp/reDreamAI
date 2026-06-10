"""Client for the AI service (apps/ai).

Defines a `BaseAiClient` protocol so the chat handler can be tested with a
`FakeAiClient` (see tests/conftest.py). The HTTP implementation talks to the
stateless `apps/ai` service over JSON/HTTPX.

Contract reference:
- POST /chat            : full conversation history → next stage + response
- POST /safety/classify : user text → risk classification (ADR 0005)
- POST /audio/transcribe: multipart audio → transcript (ADR 0010)
- POST /rehearsal/generate: dream → audio_url + script + duration
"""

from __future__ import annotations

import logging
from typing import Any, Protocol

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)


class AIServiceError(Exception):
    """Raised when the AI service returns a non-2xx response or is unreachable."""


class BaseAiClient(Protocol):
    """The chat/audio surface the backend depends on. Tests substitute a fake."""

    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]: ...
    async def safety_classify(self, payload: dict[str, Any]) -> dict[str, Any]: ...
    async def transcribe(self, *, file_name: str, audio_bytes: bytes) -> dict[str, Any]: ...
    async def rehearsal_generate(self, payload: dict[str, Any]) -> dict[str, Any]: ...


class HttpxAiClient:
    """Production `BaseAiClient` — talks to the AI service via httpx."""

    def __init__(
        self,
        *,
        base_url: str | None = None,
        timeout: float | None = None,
    ) -> None:
        self._base_url = (base_url or settings.ai_service_url).rstrip("/")
        self._timeout = timeout or settings.ai_request_timeout

    def _url(self, path: str) -> str:
        return f"{self._base_url}{path}"

    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            r = await client.post(self._url("/chat"), json=payload)
        if r.status_code >= 300:
            raise AIServiceError(f"/chat failed: {r.status_code} {r.text[:200]}")
        return r.json()

    async def safety_classify(self, payload: dict[str, Any]) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            r = await client.post(self._url("/safety/classify"), json=payload)
        if r.status_code >= 300:
            raise AIServiceError(f"/safety/classify failed: {r.status_code} {r.text[:200]}")
        return r.json()

    async def transcribe(self, *, file_name: str, audio_bytes: bytes) -> dict[str, Any]:
        files = {"file": (file_name, audio_bytes, "application/octet-stream")}
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            r = await client.post(self._url("/audio/transcribe"), files=files)
        if r.status_code >= 300:
            raise AIServiceError(f"/audio/transcribe failed: {r.status_code} {r.text[:200]}")
        return r.json()

    async def rehearsal_generate(self, payload: dict[str, Any]) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            r = await client.post(self._url("/rehearsal/generate"), json=payload)
        if r.status_code >= 300:
            raise AIServiceError(
                f"/rehearsal/generate failed: {r.status_code} {r.text[:200]}"
            )
        return r.json()


# ---------------------------------------------------------------------------
# Module-level dependency hook (overridden in tests).
# ---------------------------------------------------------------------------


_default_client: BaseAiClient | None = None


def get_ai_client() -> BaseAiClient:
    """FastAPI dependency. Returns the process-wide AI client."""
    global _default_client
    if _default_client is None:
        _default_client = HttpxAiClient()
    return _default_client
