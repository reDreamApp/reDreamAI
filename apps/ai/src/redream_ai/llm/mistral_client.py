"""Mistral SDK adapter implementing `LlmClient` (ADR 0010 — pinned models).

This file is the only place that imports the Mistral SDK. Routes depend on
the `LlmClient` protocol.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from mistralai.client import Mistral
from mistralai.client.utils import BackoffStrategy, RetryConfig

from .base import StreamChunk

# One slow or rate-limited call must not sink the whole chat turn: time out each
# request after 25s and retry 429/5xx/timeouts with backoff for up to 40s.
REQUEST_TIMEOUT_MS = 25_000
RETRY = RetryConfig(
    "backoff",
    BackoffStrategy(
        initial_interval=500, max_interval=8_000, exponent=2.0, max_elapsed_time=40_000
    ),
    retry_connection_errors=True,
)


def make_client(api_key: str, *, timeout_ms: int = REQUEST_TIMEOUT_MS) -> Mistral:
    if not api_key:
        raise ValueError("MISTRAL_API_KEY must be set")
    return Mistral(api_key=api_key, retry_config=RETRY, timeout_ms=timeout_ms)


class MistralLlmClient:
    """Production `LlmClient` backed by the Mistral API."""

    def __init__(self, api_key: str) -> None:
        self._client = make_client(api_key)

    async def chat(
        self,
        *,
        model: str,
        messages: list[dict[str, Any]],
        temperature: float = 0.5,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
        reasoning_effort: str | None = None,
    ) -> tuple[str, dict[str, int]]:
        kwargs: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
        }
        if max_tokens is not None:
            kwargs["max_tokens"] = max_tokens
        if response_format is not None:
            kwargs["response_format"] = response_format
        if reasoning_effort is not None:
            kwargs["reasoning_effort"] = reasoning_effort

        response = await self._client.chat.complete_async(**kwargs)
        message = response.choices[0].message if response.choices else None
        content = _text(message.content) if message else ""
        usage = {
            "input_tokens": int(response.usage.prompt_tokens or 0),
            "output_tokens": int(response.usage.completion_tokens or 0),
        }
        return content, usage

    async def chat_stream(
        self,
        *,
        model: str,
        messages: list[dict[str, Any]],
        temperature: float = 0.5,
        max_tokens: int | None = None,
        reasoning_effort: str | None = None,
    ) -> AsyncIterator[StreamChunk]:
        kwargs: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
        }
        if max_tokens is not None:
            kwargs["max_tokens"] = max_tokens
        if reasoning_effort is not None:
            kwargs["reasoning_effort"] = reasoning_effort

        stream = await self._client.chat.stream_async(**kwargs)
        async for chunk in stream:
            data = chunk.data
            choice = data.choices[0] if data.choices else None
            text = _text(choice.delta.content) if choice and choice.delta else ""
            finish_reason = choice.finish_reason if choice else None
            usage = getattr(data, "usage", None)

            out: StreamChunk = {"text": text}
            if finish_reason:
                out["finish_reason"] = finish_reason
            if usage is not None:
                out["input_tokens"] = int(usage.prompt_tokens or 0)
                out["output_tokens"] = int(usage.completion_tokens or 0)
            yield out


def _text(content: Any) -> str:
    """Message content is a string or, for multimodal replies, a list of chunks."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    parts: list[str] = []
    for chunk in content:
        text = chunk.get("text") if isinstance(chunk, dict) else getattr(chunk, "text", None)
        if isinstance(text, str):
            parts.append(text)
    return "".join(parts)
