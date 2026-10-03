"""GDPR purge: Langfuse trace deletion + the /users/me/data route.

`delete_user_traces` deletes straight in Langfuse's database (v2 has no API
for it). The tests point it at a throwaway SQLite file carrying the four
Langfuse tables it touches, reduced to the columns it uses.
"""

from __future__ import annotations

from typing import Any
from uuid import uuid4

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from redream_api.services import langfuse_service

_SCHEMA = [
    "CREATE TABLE trace_sessions (id TEXT PRIMARY KEY)",
    "CREATE TABLE traces (id TEXT PRIMARY KEY, user_id TEXT, session_id TEXT, input TEXT)",
    "CREATE TABLE observations (id TEXT PRIMARY KEY, trace_id TEXT)",
    "CREATE TABLE scores (id TEXT PRIMARY KEY, trace_id TEXT)",
]


@pytest.fixture
async def langfuse_db(tmp_path, monkeypatch):
    """A Langfuse-shaped database; yields a helper that runs SQL against it."""
    url = f"sqlite+aiosqlite:///{tmp_path / 'langfuse.db'}"
    engine = create_async_engine(url)
    async with engine.begin() as conn:
        for statement in _SCHEMA:
            await conn.execute(text(statement))
    monkeypatch.setattr(langfuse_service.settings, "langfuse_database_url", url)

    async def run(sql: str, **params: Any) -> list[Any]:
        async with engine.begin() as conn:
            result = await conn.execute(text(sql), params)
            return list(result.scalars().all()) if result.returns_rows else []

    yield run
    await engine.dispose()


async def _add_trace(run, trace_id: str, *, user_id: str | None, session_id: str | None) -> None:
    if session_id is not None:
        await run("INSERT OR IGNORE INTO trace_sessions (id) VALUES (:s)", s=session_id)
    await run(
        "INSERT INTO traces (id, user_id, session_id, input) VALUES (:t, :u, :s, 'a nightmare')",
        t=trace_id,
        u=user_id,
        s=session_id,
    )
    for table in ("observations", "scores"):
        await run(
            f"INSERT INTO {table} (id, trace_id) VALUES (:i, :t)",
            i=f"{table}-{trace_id}",
            t=trace_id,
        )


async def test_deletes_everything_of_the_user_and_nothing_else(langfuse_db):
    user, other = str(uuid4()), str(uuid4())
    await _add_trace(langfuse_db, "tr-1", user_id=user, session_id="11")
    await _add_trace(langfuse_db, "tr-2", user_id=user, session_id="11")
    await _add_trace(langfuse_db, "tr-3", user_id=user, session_id=None)
    await _add_trace(langfuse_db, "tr-other", user_id=other, session_id="22")
    await _add_trace(langfuse_db, "tr-untagged", user_id=None, session_id=None)

    assert await langfuse_service.delete_user_traces(user) is True

    kept = ["tr-other", "tr-untagged"]
    assert sorted(await langfuse_db("SELECT id FROM traces")) == kept
    assert sorted(await langfuse_db("SELECT trace_id FROM observations")) == kept
    assert sorted(await langfuse_db("SELECT trace_id FROM scores")) == kept
    # The user's chat session goes with its traces; the other user's stays.
    assert await langfuse_db("SELECT id FROM trace_sessions") == ["22"]


async def test_session_with_someone_elses_trace_survives(langfuse_db):
    """Sessions are only removed once empty — never out from under a trace."""
    user, other = str(uuid4()), str(uuid4())
    await _add_trace(langfuse_db, "tr-mine", user_id=user, session_id="shared")
    await _add_trace(langfuse_db, "tr-theirs", user_id=other, session_id="shared")

    assert await langfuse_service.delete_user_traces(user) is True

    assert await langfuse_db("SELECT id FROM traces") == ["tr-theirs"]
    assert await langfuse_db("SELECT id FROM trace_sessions") == ["shared"]


async def test_no_traces_is_success(langfuse_db):
    await _add_trace(langfuse_db, "tr-other", user_id=str(uuid4()), session_id="22")

    assert await langfuse_service.delete_user_traces(uuid4()) is True
    assert await langfuse_db("SELECT id FROM traces") == ["tr-other"]


async def test_database_failure_returns_false(monkeypatch, tmp_path):
    """Best-effort: an unusable Langfuse database must not raise into the purge."""
    empty = f"sqlite+aiosqlite:///{tmp_path / 'no-langfuse-tables.db'}"
    monkeypatch.setattr(langfuse_service.settings, "langfuse_database_url", empty)

    assert await langfuse_service.delete_user_traces(uuid4()) is False


async def test_unconfigured_langfuse_returns_false(monkeypatch):
    monkeypatch.setattr(langfuse_service.settings, "langfuse_database_url", "")

    assert await langfuse_service.delete_user_traces(uuid4()) is False


async def test_ai_calls_carry_user_and_session_ids(client, fake_ai, fake_user):
    """Both AI calls of a turn must send user_id/session_id — apps/ai stamps
    them on the Langfuse traces the purge later deletes by user id."""
    from .conftest import start_chat

    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more.",
            "structured": None,
            "usage": {"input_tokens": 1, "output_tokens": 1},
            "prompt_version": "test-v0",
        }
    )
    chat_id = await start_chat(client)
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "a nightmare"})
    assert r.status_code == 200

    by_method = {c["method"]: c["payload"] for c in fake_ai.calls}
    for method in ("safety_classify", "chat"):
        assert by_method[method]["user_id"] == str(fake_user.id)
        assert by_method[method]["session_id"] == str(chat_id)


async def test_purge_route_reaches_postgres_storage_and_langfuse(
    client, fake_user, db_session_maker, monkeypatch
):
    """DELETE /users/me/data must clear all three stores (apps/api invariant)."""
    from redream_api.api.v1.users import routes as user_routes

    calls: dict[str, Any] = {}

    async def fake_storage(user_id):
        calls["storage"] = user_id

    async def fake_langfuse(user_id):
        calls["langfuse"] = user_id
        return True

    monkeypatch.setattr(user_routes, "delete_rehearsal_audio_for_user", fake_storage)
    monkeypatch.setattr(user_routes, "delete_user_traces", fake_langfuse)

    r = await client.delete("/api/v1/users/me/data")
    assert r.status_code == 204

    assert calls == {"storage": fake_user.id, "langfuse": fake_user.id}
    from redream_api.db.repositories.user_repo import UserRepo

    async with db_session_maker() as session:
        assert await UserRepo(session).get(fake_user.id) is None
