"""POST /api/v1/audio/transcribe — voice journaling proxy (ADR 0008 + 0010)."""

from __future__ import annotations

import pytest

from redream_api.db.repositories.usage_repo import UsageRepo
from redream_api.services.ai_client import AIServiceError

from .conftest import FakeAiClient, seed_usage


def _upload(content: bytes = b"fake-audio"):
    return {"file": ("dream.m4a", content, "audio/mp4")}


async def test_transcribe_returns_text_and_records_usage(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
):
    fake_ai.queue_transcribe(
        {
            "text": "I was chased through a forest.",
            "language_detected": "en",
            "input_tokens": 300,
            "output_tokens": 22,
        }
    )

    r = await client.post("/api/v1/audio/transcribe", files=_upload())

    assert r.status_code == 200
    body = r.json()
    assert body["text"] == "I was chased through a forest."
    assert body["language_detected"] == "en"

    # Transcription tokens hit the same daily budget as chat (ADR 0008).
    call = fake_ai.calls[0]
    assert call["method"] == "transcribe"
    assert call["file_name"] == "dream.m4a"
    async with db_session_maker() as session:
        assert await UsageRepo(session).get_today_tokens(fake_user.id) == 322


async def test_transcribe_blocked_when_budget_exhausted(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
):
    await seed_usage(db_session_maker, user_id=fake_user.id, tokens=100_000)

    r = await client.post("/api/v1/audio/transcribe", files=_upload())

    assert r.status_code == 429
    assert "Retry-After" in r.headers
    assert fake_ai.calls == []  # never forwarded to the AI service


async def test_transcribe_ai_failure_is_502(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
):
    fake_ai.queue_transcribe_error(AIServiceError("both providers down"))

    r = await client.post("/api/v1/audio/transcribe", files=_upload())

    assert r.status_code == 502
    # A failed transcription gives its reservation back.
    async with db_session_maker() as session:
        assert await UsageRepo(session).get_today_tokens(fake_user.id) == 0
        assert await UsageRepo(session).get_today_total() == 0


async def test_transcribe_oversized_audio_is_413(client, fake_ai: FakeAiClient, monkeypatch):
    from redream_api.api.v1.audio import routes as audio_routes

    monkeypatch.setattr(audio_routes, "MAX_AUDIO_BYTES", 10)

    r = await client.post("/api/v1/audio/transcribe", files=_upload(b"x" * 11))

    assert r.status_code == 413
    assert fake_ai.calls == []


@pytest.mark.parametrize("tokens", [(0, 0)])
async def test_zero_usage_retains_the_reservation(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker, tokens
):
    fake_ai.queue_transcribe({"text": "hi", "input_tokens": tokens[0], "output_tokens": tokens[1]})

    r = await client.post("/api/v1/audio/transcribe", files=_upload())

    assert r.status_code == 200
    async with db_session_maker() as session:
        assert await UsageRepo(session).get_today_tokens(fake_user.id) == 8192
