"""FastAPI app factory.

Run with:
    uvicorn redream_ai.main:app --host 0.0.0.0 --port 8080
"""

from __future__ import annotations

from fastapi import FastAPI

from .api import audio, chat, health, safety

app = FastAPI(title="reDreamAI — AI service", version="0.1.0")

app.include_router(health.router)
app.include_router(chat.router)
app.include_router(safety.router)
app.include_router(audio.router)
