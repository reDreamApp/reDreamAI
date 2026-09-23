"""FastAPI app factory.

Run with:
    uvicorn redream_api.main:app --host 0.0.0.0 --port 8001
"""

from __future__ import annotations

from fastapi import FastAPI

from .api.router import router_internal, router_v1
from .core.logging import configure_logging

configure_logging()

app = FastAPI(title="reDreamAI — backend", version="0.1.0")
app.include_router(router_v1, prefix="/api/v1")
app.include_router(router_internal, prefix="/internal")
