"""Client for the AI service (apps/ai).

Defines a `BaseAiClient` protocol so the chat handler can be tested with a
`FakeAiClient` (see tests/conftest.py). The HTTP implementation talks to the
stateless `apps/ai` service over JSON/HTTPX.

Contract reference:
- POST /chat            : full conversation history → next stage + response
- POST /chat/stream     : same request → SSE frames (ADR 0009); the frame
                          contract is documented in apps/ai's api/chat.py
- POST /safety/classify : user text → risk classification (ADR 0005)
- POST /audio/transcribe: multipart audio → transcript (ADR 0010)
- POST /rehearsal/generate: dream → audio_url + script + duration
"""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any, Protocol

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)


# apps/ai allows Voxtral two 60s attempts plus the Storage calls.
_REHEARSAL_TIMEOUT = 150.0


class AIServiceError(Exception):
    """Raised when the AI service returns a non-2xx response or is unreachable."""


class BaseAiClient(Protocol):
    """The chat/audio surface the backend depends on. Tests substitute a fake."""

    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]: ...
    def chat_stream(self, payload: dict[str, Any]) -> AsyncIterator[str]: ...
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

    async def chat_stream(self, payload: dict[str, Any]) -> AsyncIterator[str]:
        """POST /chat/stream — yields one SSE frame per item (``data: <payload>``,
        stripped, without the ``\\n\\n`` separator). Raises AIServiceError on a
        non-2xx status (read fully before any frame is yielded)."""
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            async with client.stream(
                "POST", self._url("/chat/stream"), json=payload
            ) as r:
                if r.status_code >= 300:
                    body = (await r.aread()).decode(errors="replace")
                    raise AIServiceError(
                        f"/chat/stream failed: {r.status_code} {body[:200]}"
                    )
                buffer = ""
                async for chunk in r.aiter_text():
                    buffer += chunk
                    while "\n\n" in buffer:
                        frame, buffer = buffer.split("\n\n", 1)
                        if frame.strip():
                            yield frame.strip()
                if buffer.strip():
                    yield buffer.strip()

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
        # Synthesizing a whole rewritten dream (with one provider retry) can
        # outlast the chat timeout.
        timeout = max(self._timeout, _REHEARSAL_TIMEOUT)
        async with httpx.AsyncClient(timeout=timeout) as client:
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
