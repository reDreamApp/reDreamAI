"""pytest fixtures for the backend.

Per-test SQLite file, dependency overrides for `get_db`, `get_current_user`
and `get_ai_client`. No live Supabase, no live AI.
"""

from __future__ import annotations

import os
import tempfile
from collections.abc import AsyncIterator, Iterator
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

# Set env BEFORE importing redream_api so the global Settings constructs cleanly.
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("REPORT_NOTIFICATION_HMAC_SECRET", "test-secret-do-not-use-in-prod")
os.environ.setdefault("REPORT_ACTION_BASE_URL", "http://test/internal")

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from redream_api.core.clock import today_utc
from redream_api.core.dependencies import get_current_user, get_db
from redream_api.db import models as _models  # noqa: F401 — register tables
from redream_api.db.base import Base
from redream_api.db.models.user import User
from redream_api.db.models.user_daily_usage import UserDailyUsage
from redream_api.main import app
from redream_api.services.ai_client import get_ai_client


class FakeAiClient:
    """A queue-driven test double for the AI service.

    Use `queue_chat`, `queue_safety`, `queue_transcribe`, `queue_rehearsal` to
    pre-load responses. Calls are recorded on `self.calls` for assertions.

    Default behaviour (queue empty) for `safety_classify` is `risk=none` —
    that's the common case and keeps tests focused on the interesting paths.
    """

    def __init__(self) -> None:
        self._chat: list[dict[str, Any]] = []
        self._safety: list[dict[str, Any]] = []
        self._transcribe: list[dict[str, Any]] = []
        self._rehearsal: list[dict[str, Any]] = []
        self.calls: list[dict[str, Any]] = []

    def queue_chat(self, response: dict[str, Any]) -> None:
        self._chat.append(response)

    def queue_safety(self, response: dict[str, Any]) -> None:
        self._safety.append(response)

    def queue_transcribe(self, response: dict[str, Any]) -> None:
        self._transcribe.append(response)

    def queue_rehearsal(self, response: dict[str, Any]) -> None:
        self._rehearsal.append(response)

    async def chat(self, payload: dict[str, Any]) -> dict[str, Any]:
        self.calls.append({"method": "chat", "payload": payload})
        if not self._chat:
            raise RuntimeError("FakeAiClient: no chat response queued")
        return self._chat.pop(0)

    async def safety_classify(self, payload: dict[str, Any]) -> dict[str, Any]:
        self.calls.append({"method": "safety_classify", "payload": payload})
        if not self._safety:
            return {
                "risk": "none",
                "categories": [],
                "confidence": 0.0,
                "prompt_version": "fake-safety-v0",
            }
        return self._safety.pop(0)

    async def transcribe(self, *, file_name: str, audio_bytes: bytes) -> dict[str, Any]:
        self.calls.append(
            {"method": "transcribe", "file_name": file_name, "size": len(audio_bytes)}
        )
        if not self._transcribe:
            raise RuntimeError("FakeAiClient: no transcribe response queued")
        return self._transcribe.pop(0)

    async def rehearsal_generate(self, payload: dict[str, Any]) -> dict[str, Any]:
        self.calls.append({"method": "rehearsal_generate", "payload": payload})
        if not self._rehearsal:
            raise RuntimeError("FakeAiClient: no rehearsal response queued")
        return self._rehearsal.pop(0)


@pytest.fixture
def db_path() -> Iterator[Path]:
    fd, path_str = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    path = Path(path_str)
    try:
        yield path
    finally:
        path.unlink(missing_ok=True)


@pytest.fixture
async def db_engine(db_path: Path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    try:
        yield engine
    finally:
        await engine.dispose()


@pytest.fixture
async def db_session_maker(db_engine):
    return async_sessionmaker(bind=db_engine, expire_on_commit=False, class_=AsyncSession)


@pytest.fixture
async def db(db_session_maker) -> AsyncIterator[AsyncSession]:
    async with db_session_maker() as session:
        yield session


@pytest.fixture
async def fake_user(db_session_maker) -> User:
    async with db_session_maker() as session:
        user = User(id=uuid4(), email="test@example.com")
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user


@pytest.fixture
def fake_ai() -> FakeAiClient:
    return FakeAiClient()


@pytest.fixture
async def client(db_session_maker, fake_user, fake_ai) -> AsyncIterator[AsyncClient]:
    """HTTP client with deps overridden to use the per-test DB + fake AI + fake user."""

    async def _db_dep() -> AsyncIterator[AsyncSession]:
        async with db_session_maker() as session:
            yield session

    async def _user_dep() -> User:
        return fake_user

    def _ai_dep() -> FakeAiClient:
        return fake_ai

    app.dependency_overrides[get_db] = _db_dep
    app.dependency_overrides[get_current_user] = _user_dep
    app.dependency_overrides[get_ai_client] = _ai_dep

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


async def start_chat(client: AsyncClient, language: str = "en") -> int:
    r = await client.post("/api/v1/chats/start", json={"language": language})
    assert r.status_code == 201, r.text
    return int(r.json()["chat_id"])


async def seed_usage(db_session_maker, *, user_id: UUID, tokens: int) -> None:
    """Seed today's UserDailyUsage row directly. Used by token-budget tests."""
    async with db_session_maker() as session:
        session.add(UserDailyUsage(user_id=user_id, usage_date=today_utc(), llm_tokens=tokens))
        await session.commit()
