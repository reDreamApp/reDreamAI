"""Langfuse tracing (ADR 0007 — self-hosted Langfuse v2).

This is the ONLY module that imports the Langfuse SDK. Every other module calls
the version-neutral helpers here, so swapping Langfuse major versions later is a
single-file change.

Tracing is OPTIONAL. When ``LANGFUSE_HOST`` / keys are unset (tests, offline
dev) every helper degrades to a no-op and returns ``None``. Any failure inside
the SDK is swallowed with a warning — observability must never break a chat
turn.

A trace handle is whatever ``client.trace()`` returns (or ``None`` when tracing
is disabled). Callers treat it as opaque and pass it back into the helpers.
"""

from __future__ import annotations

import logging
from typing import Any

from .config import settings

log = logging.getLogger(__name__)

Trace = Any

_client: Any = None
_initialized = False


def _get_client() -> Any:
    """Lazily build the Langfuse client. Returns ``None`` when tracing is disabled."""
    global _client, _initialized
    if _initialized:
        return _client
    _initialized = True

    if not (
        settings.langfuse_host
        and settings.langfuse_public_key
        and settings.langfuse_secret_key
    ):
        log.info("Langfuse tracing disabled (LANGFUSE_HOST / keys not set).")
        return None

    try:
        from langfuse import Langfuse

        _client = Langfuse(
            host=settings.langfuse_host,
            public_key=settings.langfuse_public_key,
            secret_key=settings.langfuse_secret_key,
        )
        log.info("Langfuse tracing enabled (host=%s).", settings.langfuse_host)
    except Exception as exc:  # never let observability break startup
        log.warning("Langfuse init failed; tracing disabled: %s", exc)
        _client = None
    return _client


def start_trace(
    name: str,
    *,
    session_id: str | None = None,
    input: Any = None,
    metadata: dict[str, Any] | None = None,
) -> Trace:
    """Begin a trace for one AI request. Returns ``None`` when tracing is disabled."""
    client = _get_client()
    if client is None:
        return None
    try:
        return client.trace(
            name=name,
            session_id=session_id,
            input=input,
            metadata=metadata,
        )
    except Exception as exc:
        log.warning("Langfuse start_trace failed: %s", exc)
        return None


def record_generation(
    trace: Trace,
    *,
    name: str,
    model: str,
    input: Any,
    output: str,
    usage: dict[str, int],
    metadata: dict[str, Any] | None = None,
) -> None:
    """Record one LLM call as a generation under ``trace``. No-op if trace is None."""
    if trace is None:
        return
    try:
        trace.generation(
            name=name,
            model=model,
            input=input,
            output=output,
            usage={
                "input": usage.get("input_tokens", 0),
                "output": usage.get("output_tokens", 0),
                "unit": "TOKENS",
            },
            metadata=metadata,
        )
    except Exception as exc:
        log.warning("Langfuse record_generation failed: %s", exc)


def update_trace(
    trace: Trace,
    *,
    output: Any = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Attach the final output/metadata to ``trace``. No-op if trace is None."""
    if trace is None:
        return
    try:
        trace.update(output=output, metadata=metadata)
    except Exception as exc:
        log.warning("Langfuse update_trace failed: %s", exc)


def flush() -> None:
    """Flush buffered events. Call on shutdown so nothing is lost on exit."""
    client = _get_client()
    if client is None:
        return
    try:
        client.flush()
    except Exception as exc:
        log.warning("Langfuse flush failed: %s", exc)
