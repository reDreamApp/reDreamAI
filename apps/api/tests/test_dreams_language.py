"""dreams.language: set from the chat at the summary, optional on manual
dreams, and the language rehearsal audio is generated (and cached) in."""

from __future__ import annotations

import os
import re
import sqlite3
import tempfile
from pathlib import Path
from typing import Any
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from redream_api.db.base import Base
from redream_api.db.models.chat import Chat
from redream_api.db.models.dream import Dream
from redream_api.db.models.user import User

from .conftest import FakeAiClient

_MIGRATION = (
    Path(__file__).resolve().parents[3]
    / "supabase"
    / "migrations"
    / "20261023000001_dreams_language.sql"
)


async def _create(client, **extra: Any) -> dict[str, Any]:
    r = await client.post(
        "/api/v1/dreams",
        json={
            "title": "Forest",
            "original_dream": "Lost in a forest.",
            "rewritten_dream": "You find the path home.",
            "is_nightmare": True,
            **extra,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


def _rehearsal(language: str) -> dict[str, Any]:
    return {
        "audio_url": f"https://storage.example/{language}.mp3?token=t",
        "script": "You find the path home.",
        "duration_estimate": "0:03",
        "voice_id": "voice",
        "cache_hit": False,
        "synthesis_attempts": 1,
    }


async def test_manual_dream_language_is_optional(client) -> None:
    assert (await _create(client))["language"] is None
    assert (await _create(client, language="de"))["language"] == "de"

    r = await client.post(
        "/api/v1/dreams", json={"title": "x", "original_dream": "y", "language": "fr"}
    )
    assert r.status_code == 422


async def test_update_body_cannot_set_language(client) -> None:
    dream = await _create(client, language="de")
    r = await client.put(f"/api/v1/dreams/{dream['id']}", json={"language": "en"})
    assert r.status_code == 200, r.text
    assert r.json()["language"] == "de"


async def test_rehearsal_uses_the_dream_language_and_caches_on_it(
    client, fake_ai: FakeAiClient, monkeypatch
) -> None:
    from redream_api.api.v1.dreams import routes

    async def refresh(audio_url, user_id, dream_id):
        return audio_url

    monkeypatch.setattr(routes, "refresh_rehearsal_url", refresh)
    dream = await _create(client, language="de")
    url = f"/api/v1/dreams/{dream['id']}/rehearsal"
    fake_ai.queue_rehearsal(_rehearsal("de"))

    # An older app build sends the app's language; the dream's own wins.
    r = await client.post(url, json={"language": "en"})
    assert r.status_code == 200, r.text
    assert r.json()["rehearsal_language"] == "de"
    (call,) = [c for c in fake_ai.calls if c["method"] == "rehearsal_generate"]
    assert call["payload"]["language"] == "de"

    # Same body again: served from the cache stored under the dream's language.
    r = await client.post(url, json={"language": "en"})
    assert r.status_code == 200, r.text
    assert r.json()["rehearsal_audio_url"].endswith("de.mp3?token=t")
    assert [c["method"] for c in fake_ai.calls] == ["rehearsal_generate"]


async def test_rehearsal_without_dream_language_uses_the_body(
    client, fake_ai: FakeAiClient
) -> None:
    dream = await _create(client)
    fake_ai.queue_rehearsal(_rehearsal("de"))

    r = await client.post(f"/api/v1/dreams/{dream['id']}/rehearsal", json={"language": "de"})

    assert r.status_code == 200, r.text
    assert r.json()["rehearsal_language"] == "de"
    (call,) = [c for c in fake_ai.calls if c["method"] == "rehearsal_generate"]
    assert call["payload"]["language"] == "de"


def _sqlite_dialect(sql: str) -> str:
    """The migration's Postgres-only syntax, spelled for SQLite."""
    sql = sql.replace("public.", "")
    return re.sub(r"([\w.]+)::text", r"CAST(\1 AS TEXT)", sql)


def test_migration_backfills_chatbot_dreams_and_matches_the_orm() -> None:
    """Applies the migration to the schema as it was before it (the ORM
    tables without dreams.language). CI applies it to real Postgres."""
    fd, name = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    path = Path(name)
    try:
        engine = create_engine(f"sqlite:///{path}")
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            user, other = User(id=uuid4(), email="a@x"), User(id=uuid4(), email="b@x")
            session.add_all([user, other])
            session.flush()
            de_chat = Chat(user_id=user.id, language="de")
            en_chat = Chat(user_id=user.id, language="en")
            foreign = Chat(user_id=other.id, language="de")
            session.add_all([de_chat, en_chat, foreign])
            session.flush()

            def dream(owner: User, source: str, session_id: str | None) -> Dream:
                return Dream(
                    user_id=owner.id,
                    title=source,
                    original_dream="x",
                    source=source,
                    session_id=session_id,
                )

            rows = {
                "de": dream(user, "chatbot", str(de_chat.id)),
                "en": dream(user, "chatbot", str(en_chat.id)),
                "manual": dream(user, "manual", None),
                # session_id pointing at another user's chat is not a link
                "foreign": dream(user, "chatbot", str(foreign.id)),
            }
            session.add_all(rows.values())
            session.commit()
            ids = {key: d.id for key, d in rows.items()}
        engine.dispose()

        conn = sqlite3.connect(path)
        try:
            conn.execute("ALTER TABLE dreams DROP COLUMN language")
            conn.executescript(_sqlite_dialect(_MIGRATION.read_text()))
            columns = {row[1] for row in conn.execute("PRAGMA table_info(dreams)")}
            languages = dict(conn.execute("SELECT id, language FROM dreams").fetchall())
            check_rejects = False
            try:
                conn.execute("UPDATE dreams SET language = 'fr' WHERE id = ?", (ids["manual"],))
            except sqlite3.IntegrityError:
                check_rejects = True
        finally:
            conn.close()
    finally:
        path.unlink(missing_ok=True)

    assert columns == set(Dream.__table__.columns.keys())
    assert languages[ids["de"]] == "de"
    assert languages[ids["en"]] == "en"
    assert languages[ids["manual"]] is None
    assert languages[ids["foreign"]] is None
    assert check_rejects
