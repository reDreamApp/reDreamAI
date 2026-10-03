"""Langfuse tracing (ADR 0007 — self-hosted Langfuse v2).

This is the ONLY module that imports the Langfuse SDK. Every other module calls
the version-neutral helpers here, or uses the ``observe`` / ``langfuse_context``
decorator API re-exported below (the ported IRT core in ``core/irt_app.py``
does), so swapping Langfuse major versions later is a single-file change.

Tracing is OPTIONAL. When ``LANGFUSE_HOST`` / keys are unset, or
``LANGFUSE_ENABLED=false`` (tests, offline dev), every helper degrades to a
no-op and returns ``None``, and ``configure_decorators()`` disables the
decorator context so every ``@observe`` runs untraced — zero network attempts.
Any failure inside the SDK is swallowed with a warning — observability must
never break a chat turn.

A trace handle is whatever ``client.trace()`` returns (or ``None`` when tracing
is disabled). Callers treat it as opaque and pass it back into the helpers.
"""

from __future__ import annotations

import logging
from typing import Any

# Explicit ``as`` re-exports: the vendored core imports these from here instead
# of from the SDK, keeping this module the single Langfuse entry point.
from langfuse.decorators import langfuse_context as langfuse_context
from langfuse.decorators import observe as observe

from .config import settings

log = logging.getLogger(__name__)

Trace = Any

_client: Any = None
_initialized = False
_decorators_configured = False


def _tracing_configured() -> bool:
    """True when settings enable tracing AND host/keys are all present."""
    return bool(
        settings.langfuse_enabled
        and settings.langfuse_host
        and settings.langfuse_public_key
        and settings.langfuse_secret_key
    )


def _get_client() -> Any:
    """Lazily build the Langfuse client. Returns ``None`` when tracing is disabled."""
    global _client, _initialized
    if _initialized:
        return _client
    _initialized = True

    if not _tracing_configured():
        log.info(
            "Langfuse tracing disabled (LANGFUSE_HOST / keys not set, or LANGFUSE_ENABLED=false)."
        )
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


def configure_decorators() -> None:
    """Configure the ``@observe`` decorator context from settings.

    Runs once at import of this module (below) so the gate binds for EVERY
    ``@observe`` call — including scripts and targeted test runs that never go
    through main.lifespan. Without that, the v2 decorators lazily build their
    own client from raw env vars (which never read ``LANGFUSE_ENABLED``),
    silently bypassing the off-switch. The main.lifespan call is an idempotent
    re-assert: repeat calls early-return, which also matters because the SDK's
    ``configure()`` resets its singleton with a ~2s consumer-thread join.

    When host/keys are unset or ``LANGFUSE_ENABLED=false``, the context is
    configured with ``enabled=False`` so every ``@observe`` is a true no-op:
    no client auth, no buffering, no network.
    """
    global _decorators_configured
    if _decorators_configured:
        return
    try:
        if _tracing_configured():
            langfuse_context.configure(
                host=settings.langfuse_host,
                public_key=settings.langfuse_public_key,
                secret_key=settings.langfuse_secret_key,
                enabled=True,
            )
            log.info(
                "Langfuse decorator tracing enabled (host=%s).", settings.langfuse_host
            )
        else:
            langfuse_context.configure(enabled=False)
            log.info(
                "Langfuse decorator tracing disabled "
                "(LANGFUSE_HOST / keys not set, or LANGFUSE_ENABLED=false)."
            )
        _decorators_configured = True
    except Exception as exc:  # never let observability break startup
        log.warning("Langfuse decorator configure failed; tracing disabled: %s", exc)
        try:
            langfuse_context.configure(enabled=False)
            _decorators_configured = True
        except Exception:
            pass


def start_trace(
    name: str,
    *,
    session_id: str | None = None,
    user_id: str | None = None,
    input: Any = None,
    metadata: dict[str, Any] | None = None,
) -> Trace:
    """Begin a trace for one AI request. Returns ``None`` when tracing is disabled.

    ``user_id`` matters beyond analytics: the backend's GDPR purge deletes
    Langfuse traces by userId, so an untagged trace is an unerasable one.
    """
    client = _get_client()
    if client is None:
        return None
    try:
        return client.trace(
            name=name,
            session_id=session_id,
            user_id=user_id,
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
    """Flush buffered events (client + decorator context). Call on shutdown."""
    client = _get_client()
    if client is not None:
        try:
            client.flush()
        except Exception as exc:
            log.warning("Langfuse flush failed: %s", exc)
    # Only touch the decorator context if configure_decorators() ran: its
    # flush() would otherwise lazily instantiate a client just to flush nothing.
    if _decorators_configured:
        try:
            langfuse_context.flush()
        except Exception as exc:
            log.warning("Langfuse decorator flush failed: %s", exc)


# Bind the gate at import: every module that can reach an @observe-decorated
# function imports (directly or transitively) from this module first, so no
# code path can hit an unconfigured decorator singleton.
configure_decorators()
