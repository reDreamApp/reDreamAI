"""FastAPI app factory.

Run with:
    uvicorn redream_ai.main:app --host 0.0.0.0 --port 8080
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .api import audio, chat, health, safety
from .api.chat import get_llm_client
from .config import settings
from .llm.base import LlmClient, LlmUnavailableError


def _build_llm_client() -> LlmClient | None:
    """Construct the production Mistral client; returns None if no API key set."""
    if not settings.mistral_api_key:
        return None
    from .llm.mistral_client import MistralLlmClient

    return MistralLlmClient(api_key=settings.mistral_api_key)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    import logging

    from . import observability as obs
    from .core import irt_app

    log = logging.getLogger("redream_ai.startup")

    # Crisis classifier (ADR 0005) still uses the direct-Mistral LlmClient.
    app.state.llm_client = _build_llm_client()

    # Warmth check for the ported IRT pipeline (agents + SafetyCritic build eagerly
    # at import; here we surface their status as a deep health signal, §7.4).
    agents_ready = irt_app.routing_agent is not None and irt_app.response_agent is not None
    app.state.irt_ready = agents_ready
    app.state.safety_ready = irt_app.safety_critic is not None
    if not agents_ready:
        log.warning("IRT agents UNCONFIGURED — set SCALEWAY_API_KEY + MISTRAL_API_KEY; /chat → 503")
    else:
        log.info(
            "IRT pipeline ready (agents=ok, safety_critic=%s)",
            "ok" if app.state.safety_ready else "disabled (fail-open)",
        )
    try:
        yield
    finally:
        # Flush buffered Langfuse events so nothing is lost on shutdown.
        obs.flush()


app = FastAPI(
    title="reDreamAI — AI service",
    version="0.1.0",
    lifespan=lifespan,
)


async def _llm_dep() -> LlmClient:
    client: LlmClient | None = app.state.llm_client
    if client is None:
        raise RuntimeError("LLM client not configured (set MISTRAL_API_KEY)")
    return client


app.dependency_overrides[get_llm_client] = _llm_dep


@app.exception_handler(LlmUnavailableError)
async def _llm_unavailable_handler(_: Request, exc: LlmUnavailableError) -> JSONResponse:
    return JSONResponse(
        status_code=503,
        content={"detail": f"LLM provider temporarily unavailable: {exc}"},
        headers={"Retry-After": "10"},
    )

app.include_router(health.router)
app.include_router(chat.router)
app.include_router(safety.router)
app.include_router(audio.router)
