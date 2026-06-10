"""Daily LLM token budget gate (ADR 0008)."""

from __future__ import annotations

from sqlalchemy import select

from redream_api.db.models.user_daily_usage import UserDailyUsage

from .conftest import FakeAiClient, seed_usage, start_chat


async def test_429_when_budget_already_exhausted(
    client, fake_user, db_session_maker
) -> None:
    chat_id = await start_chat(client)
    await seed_usage(db_session_maker, user_id=fake_user.id, tokens=100_000)

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message",
        json={"content": "anything"},
    )
    assert r.status_code == 429
    assert "Retry-After" in r.headers
    assert int(r.headers["Retry-After"]) > 0


async def test_normal_chat_increments_usage(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    chat_id = await start_chat(client)
    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more.",
            "structured": None,
            "usage": {"input_tokens": 30, "output_tokens": 50},
            "prompt_version": "chat-v0",
        }
    )
    r = await client.post(
        f"/api/v1/chats/{chat_id}/message",
        json={"content": "first message"},
    )
    assert r.status_code == 200

    async with db_session_maker() as session:
        rows = (
            await session.scalars(
                select(UserDailyUsage).where(UserDailyUsage.user_id == fake_user.id)
            )
        ).all()
    assert len(rows) == 1
    assert rows[0].llm_tokens == 80
