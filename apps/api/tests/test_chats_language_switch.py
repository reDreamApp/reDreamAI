"""Mid-chat language switch (en <-> de).

`_pre_turn` asks the AI's /language/check about every user message, right
after persisting it and BEFORE the safety classifier (and the dev-flag skip).
On a switch `chat.language` changes from that message on, so the classifier,
the helpline text and the AI turn all use the new language, and the AI payload
carries `language_switched=True` for that one turn.
"""

from __future__ import annotations

import json
import os
import sqlite3
import tempfile
from pathlib import Path
from typing import Any
from uuid import uuid4

import httpx
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from redream_api.api.v1.chats.routes import _HELPLINE_MESSAGE
from redream_api.db.base import Base
from redream_api.db.models.chat import Chat
from redream_api.db.models.user import User
from redream_api.services import ai_client
from redream_api.services.ai_client import AIServiceError, HttpxAiClient

from .conftest import FakeAiClient, start_chat

_REAL_ASYNC_CLIENT = httpx.AsyncClient  # before any test patches it


def _reply(stage: str = "recording", **extra: Any) -> dict[str, Any]:
    return {
        "stage": stage,
        "response": "Erzähl mir mehr.",
        "structured": None,
        "usage": {"input_tokens": 1, "output_tokens": 1},
        "prompt_version": "test-v0",
        **extra,
    }


def _methods(fake_ai: FakeAiClient) -> list[str]:
    return [c["method"] for c in fake_ai.calls]


def _payload(fake_ai: FakeAiClient, method: str) -> dict[str, Any]:
    return [c for c in fake_ai.calls if c["method"] == method][-1]["payload"]


async def _stored_language(db_session_maker, chat_id: int) -> str:
    async with db_session_maker() as session:
        chat = (await session.scalars(select(Chat).where(Chat.id == chat_id))).one()
    return chat.language


async def test_message_route_switches_before_the_classifier(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_chat(_reply())

    text = "Ich hatte einen Traum über meinen Bruder."
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": text})

    assert r.status_code == 200, r.text
    assert _methods(fake_ai) == ["language_check", "safety_classify", "chat"]
    assert _payload(fake_ai, "language_check") == {
        "message": text,
        "language": "en",
        "first_message": True,
    }
    assert _payload(fake_ai, "safety_classify")["language"] == "de"
    chat_payload = _payload(fake_ai, "chat")
    assert chat_payload["language"] == "de"
    assert chat_payload["language_switched"] is True
    assert {m["language"] for m in chat_payload["messages"]} == {"de"}
    assert await _stored_language(db_session_maker, chat_id) == "de"
    chats = (await client.get("/api/v1/chats")).json()
    assert chats[0]["language"] == "de"


async def test_stream_route_switches_before_the_classifier(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "de")
    fake_ai.queue_language("en")
    fake_ai.queue_chat_stream(
        [
            "data: " + json.dumps({"content": "Tell me more."}),
            "data: " + json.dumps({"final": _reply(response="Tell me more.")}),
        ]
    )

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message/stream",
        json={"content": "I had a dream about my brother."},
    )

    assert r.status_code == 200, r.text
    assert "done" in r.text
    assert _methods(fake_ai) == ["language_check", "safety_classify", "chat_stream"]
    assert _payload(fake_ai, "safety_classify")["language"] == "en"
    stream_payload = _payload(fake_ai, "chat_stream")
    assert stream_payload["language"] == "en"
    assert stream_payload["language_switched"] is True
    assert await _stored_language(db_session_maker, chat_id) == "en"


async def test_switch_flag_is_only_set_on_the_switching_turn(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_chat(_reply())
    fake_ai.queue_chat(_reply())

    await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ich bin müde."})
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ja."})

    assert r.status_code == 200, r.text
    # Second turn: checked against the new language, no switch, no note,
    # and no longer the chat's first message.
    assert _payload(fake_ai, "language_check")["language"] == "de"
    assert _payload(fake_ai, "language_check")["first_message"] is False
    chat_payload = _payload(fake_ai, "chat")
    assert chat_payload["language"] == "de"
    assert chat_payload["language_switched"] is False
    assert await _stored_language(db_session_maker, chat_id) == "de"


async def test_dev_flag_path_still_switches(
    client, fake_ai: FakeAiClient, db_session_maker, monkeypatch
) -> None:
    from redream_api.core.config import settings

    monkeypatch.setattr(settings, "safety_classifier_enabled", False)
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_chat(_reply())

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message", json={"content": "Kannst du Deutsch reden?"}
    )

    assert r.status_code == 200, r.text
    assert _methods(fake_ai) == ["language_check", "chat"]
    chat_payload = _payload(fake_ai, "chat")
    assert chat_payload["language"] == "de"
    assert chat_payload["language_switched"] is True
    assert await _stored_language(db_session_maker, chat_id) == "de"


async def test_crisis_message_in_the_new_language_gets_its_helpline(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_safety(
        {
            "risk": "high",
            "categories": ["suicidal_ideation"],
            "confidence": 0.9,
            "prompt_version": "safety-test",
        }
    )

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message",
        json={"content": "Ich will nicht mehr hier sein."},
    )

    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "safety_classify")["language"] == "de"
    assert r.json()["safety_event"]["message"] == _HELPLINE_MESSAGE["de"]
    assert "chat" not in _methods(fake_ai)
    assert await _stored_language(db_session_maker, chat_id) == "de"


async def test_no_switch_keeps_language_and_flag_false(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_chat(_reply())  # language_check default: the current language

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "I was in Berlin."})

    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "safety_classify")["language"] == "en"
    chat_payload = _payload(fake_ai, "chat")
    assert chat_payload["language"] == "en"
    assert chat_payload["language_switched"] is False
    assert await _stored_language(db_session_maker, chat_id) == "en"


async def test_unsupported_check_answer_keeps_language(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("fr")
    fake_ai.queue_chat(_reply())

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Bonjour"})

    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "chat")["language_switched"] is False
    assert await _stored_language(db_session_maker, chat_id) == "en"


async def test_whitespace_only_message_skips_the_check(client, fake_ai: FakeAiClient) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_chat(_reply())

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "   "})

    assert r.status_code == 200, r.text
    assert "language_check" not in _methods(fake_ai)


async def test_failed_ai_turn_reverts_the_switch(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    """The 502 path drops the user message so the client can resend it; the
    switch it caused is undone too, so the retry switches (with the note)."""
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_chat_error(AIServiceError("boom"))

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ich bin da."})

    assert r.status_code == 502
    assert await _stored_language(db_session_maker, chat_id) == "en"


async def test_failed_stream_reverts_the_switch(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_chat_stream(["data: " + json.dumps({"error": "upstream exploded"})])

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message/stream", json={"content": "Ich bin da."}
    )

    assert '"error"' in r.text
    assert await _stored_language(db_session_maker, chat_id) == "en"


async def test_failed_classifier_reverts_the_switch(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    """A 502 from /safety/classify undoes the switch like a failed AI turn,
    so the client's retry switches again and carries the note."""
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_safety_error(AIServiceError("classifier down"))

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ich bin da."})

    assert r.status_code == 502
    assert await _stored_language(db_session_maker, chat_id) == "en"

    fake_ai.queue_language("de")
    fake_ai.queue_chat(_reply())
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ich bin da."})

    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "language_check")["language"] == "en"
    assert _payload(fake_ai, "chat")["language_switched"] is True
    assert await _stored_language(db_session_maker, chat_id) == "de"


async def _crisis_switch(client, fake_ai: FakeAiClient) -> int:
    """An English chat whose first message is a German crisis message."""
    chat_id = await start_chat(client, "en")
    fake_ai.queue_language("de")
    fake_ai.queue_safety({"risk": "high", "categories": ["self_harm"], "confidence": 0.9})
    r = await client.post(
        f"/api/v1/chats/{chat_id}/message", json={"content": "Ich will nicht mehr leben."}
    )
    assert r.status_code == 200, r.text
    assert r.json()["safety_event"]["message"] == _HELPLINE_MESSAGE["de"]
    return chat_id


async def test_switch_on_a_crisis_turn_notes_it_on_the_next_ai_turn(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    """The crisis turn has no AI reply, so the next AI turn carries the note,
    once."""
    chat_id = await _crisis_switch(client, fake_ai)
    fake_ai.queue_chat(_reply())
    fake_ai.queue_chat(_reply())

    wolf = {"content": "Der Wolf war groß."}
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json=wolf)
    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "language_check")["language"] == "de"
    chat_payload = _payload(fake_ai, "chat")
    assert chat_payload["language"] == "de"
    assert chat_payload["language_switched"] is True

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ja."})
    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "chat")["language_switched"] is False
    assert await _stored_language(db_session_maker, chat_id) == "de"


async def test_pending_switch_note_survives_a_failed_turn_and_streams(
    client, fake_ai: FakeAiClient
) -> None:
    chat_id = await _crisis_switch(client, fake_ai)
    fake_ai.queue_chat_error(AIServiceError("boom"))
    wolf = {"content": "Der Wolf war groß."}
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json=wolf)
    assert r.status_code == 502

    fake_ai.queue_chat_stream(
        [
            "data: " + json.dumps({"content": "Erzähl mir mehr."}),
            "data: " + json.dumps({"final": _reply()}),
        ]
    )
    r = await client.post(f"/api/v1/chats/{chat_id}/message/stream", json=wolf)
    assert "done" in r.text
    assert _payload(fake_ai, "chat_stream")["language_switched"] is True

    fake_ai.queue_chat(_reply())
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Ja."})
    assert r.status_code == 200, r.text
    assert _payload(fake_ai, "chat")["language_switched"] is False


async def test_summary_dream_stores_the_chat_language(client, fake_ai: FakeAiClient) -> None:
    chat_id = await start_chat(client, "en")
    structured = {
        "title": "Der helle Wald",
        "original_summary": "Verfolgt im Wald.",
        "rewritten_summary": "Ich gehe durch einen hellen Wald.",
    }
    fake_ai.queue_language("de")
    fake_ai.queue_chat(_reply("summary", structured=structured))

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message", json={"content": "Ja, das passt so für mich."}
    )
    assert r.status_code == 200, r.text
    (dream,) = (await client.get("/api/v1/dreams")).json()
    assert dream["language"] == "de"

    # A later summary in the other language updates the same dream.
    fake_ai.queue_language("en")
    fake_ai.queue_chat(_reply("summary", structured=structured))
    r = await client.post(
        f"/api/v1/chats/{chat_id}/message", json={"content": "Can we finish this in English?"}
    )
    assert r.status_code == 200, r.text
    (dream,) = (await client.get("/api/v1/dreams")).json()
    assert dream["language"] == "en"


# ---------------------------------------------------------------------------
# HttpxAiClient.language_check — never raises, any failure keeps the language.
# ---------------------------------------------------------------------------


def _mock_ai(monkeypatch, handler) -> tuple[list[httpx.Request], list[Any]]:
    """Route HttpxAiClient's requests to `handler`; returns (requests, timeouts)."""
    seen: list[httpx.Request] = []
    timeouts: list[Any] = []

    def _handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return handler(request)

    def _client(**kwargs: Any) -> httpx.AsyncClient:
        timeouts.append(kwargs.get("timeout"))
        return _REAL_ASYNC_CLIENT(transport=httpx.MockTransport(_handler), **kwargs)

    monkeypatch.setattr(ai_client.httpx, "AsyncClient", _client)
    return seen, timeouts


async def test_http_language_check_returns_the_new_language(monkeypatch) -> None:
    seen, timeouts = _mock_ai(
        monkeypatch,
        lambda r: httpx.Response(200, json={"language": "de", "switched": True}),
    )

    result = await HttpxAiClient(base_url="http://ai").language_check("Ich bin da.", "en")

    assert result == "de"
    assert seen[0].url.path == "/language/check"
    assert json.loads(seen[0].content) == {
        "message": "Ich bin da.",
        "language": "en",
        "first_message": False,
    }
    assert timeouts == [10.0]


async def test_http_language_check_failures_keep_the_language(monkeypatch, caplog) -> None:
    def _raise(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("slow", request=request)

    def _bug(request: httpx.Request) -> httpx.Response:
        raise RuntimeError("unexpected")

    handlers = [
        _bug,
        lambda r: httpx.Response(503, text="down"),
        lambda r: httpx.Response(200, json={"language": "fr", "switched": True}),
        lambda r: httpx.Response(200, text="not json"),
        lambda r: httpx.Response(200, json=["de"]),
        _raise,
    ]
    secret = "mein geheimer Traum"
    for handler in handlers:
        _mock_ai(monkeypatch, handler)
        with caplog.at_level("WARNING"):
            assert await HttpxAiClient(base_url="http://ai").language_check(secret, "en") == "en"

    assert len([r for r in caplog.records if "language/check" in r.getMessage()]) == 6
    assert secret not in caplog.text


def test_pending_flag_migration_matches_the_orm() -> None:
    """Applies the migration to the chats table as it was before it. CI
    applies it to real Postgres."""
    migration = (
        Path(__file__).resolve().parents[3]
        / "supabase"
        / "migrations"
        / "20261023000002_chats_language_switch_pending.sql"
    )
    fd, name = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    path = Path(name)
    try:
        engine = create_engine(f"sqlite:///{path}")
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            user = User(id=uuid4(), email="a@x")
            session.add(user)
            session.flush()
            session.add(Chat(user_id=user.id, language="de"))
            session.commit()
        engine.dispose()

        conn = sqlite3.connect(path)
        try:
            conn.execute("ALTER TABLE chats DROP COLUMN language_switch_pending")
            conn.executescript(migration.read_text().replace("public.", ""))
            columns = {row[1] for row in conn.execute("PRAGMA table_info(chats)")}
            pending = conn.execute("SELECT language_switch_pending FROM chats").fetchall()
        finally:
            conn.close()
    finally:
        path.unlink(missing_ok=True)

    assert columns == set(Chat.__table__.columns.keys())
    assert pending == [(0,)]
