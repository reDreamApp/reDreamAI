"""Mistral SDK adapter implementing `LlmClient` (ADR 0010 — pinned models).

This file is the only place that imports the Mistral SDK. Routes depend on
the `LlmClient` protocol.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from mistralai import Mistral  # type: ignore[import-untyped]

from .base import StreamChunk


class MistralLlmClient:
    """Production `LlmClient` backed by the Mistral API."""

    def __init__(self, api_key: str) -> None:
        if not api_key:
            raise ValueError("MISTRAL_API_KEY must be set")
        self._client = Mistral(api_key=api_key)

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
        content = response.choices[0].message.content or ""
        usage = {
            "input_tokens": response.usage.prompt_tokens,
            "output_tokens": response.usage.completion_tokens,
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
            text = (choice.delta.content or "") if choice and choice.delta else ""
            finish_reason = choice.finish_reason if choice else None
            usage = getattr(data, "usage", None)

            out: StreamChunk = {"text": text}
            if finish_reason:
                out["finish_reason"] = finish_reason
            if usage is not None:
                out["input_tokens"] = usage.prompt_tokens
                out["output_tokens"] = usage.completion_tokens
            yield out
