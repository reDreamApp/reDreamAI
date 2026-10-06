"""Daily LLM token budget gate (ADR 0008)."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import delete, select

from redream_api.core.config import settings
from redream_api.db.models.service_daily_usage import ServiceDailyUsage
from redream_api.db.models.user import User
from redream_api.db.models.user_daily_usage import UserDailyUsage
from redream_api.db.repositories.usage_repo import UsageRepo
from redream_api.db.repositories.user_repo import UserRepo
from redream_api.services.token_budget import check_budget, record_usage

from .conftest import FakeAiClient, seed_usage, start_chat


async def _seed_total(db_session_maker, tokens: int) -> None:
    async with db_session_maker() as session:
        session.add(
            ServiceDailyUsage(usage_date=datetime.now(UTC).date(), llm_tokens=tokens)
        )
        await session.commit()


async def test_429_when_budget_already_exhausted(client, fake_user, db_session_maker) -> None:
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


# ---------------------------------------------------------------------------
# The limit of all users together (ADR 0008, amended 2026-10-06)
# ---------------------------------------------------------------------------


def test_the_total_limit_defaults_to_500k() -> None:
    assert settings.daily_llm_token_budget_total == 500_000


async def test_429_for_everyone_when_the_total_is_used_up(
    client, fake_user, db_session_maker
) -> None:
    chat_id = await start_chat(client)
    # This user has used nothing; other accounts used up the day's total.
    await _seed_total(db_session_maker, settings.daily_llm_token_budget_total)

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "anything"})
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) > 0

    stream = await client.post(
        f"/api/v1/chats/{chat_id}/message/stream", json={"content": "anything"}
    )
    assert stream.status_code == 429


async def test_chat_works_just_below_the_total(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    chat_id = await start_chat(client)
    await _seed_total(db_session_maker, settings.daily_llm_token_budget_total - 1)
    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more.",
            "structured": None,
            "usage": {"input_tokens": 30, "output_tokens": 50},
            "prompt_version": "chat-v0",
        }
    )

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "first message"})
    assert r.status_code == 200

    async with db_session_maker() as session:
        total = await UsageRepo(session).get_today_total()
    assert total == settings.daily_llm_token_budget_total - 1 + 80


async def test_usage_of_every_user_adds_to_the_total(fake_user, db_session_maker) -> None:
    other = uuid4()
    async with db_session_maker() as session:
        session.add(User(id=other))
        await session.commit()
        await record_usage(session, user_id=fake_user.id, input_tokens=100, output_tokens=20)
        await record_usage(session, user_id=other, input_tokens=300, output_tokens=5)
        await record_usage(session, user_id=fake_user.id, input_tokens=1, output_tokens=0)

        repo = UsageRepo(session)
        assert await repo.get_today_tokens(fake_user.id) == 121
        assert await repo.get_today_tokens(other) == 305
        assert await repo.get_today_total() == 426


async def test_the_total_keeps_what_a_deleted_account_used(
    fake_user, db_session_maker, monkeypatch
) -> None:
    """Signing up, using the budget and deleting the account must not reset
    the day's total: that is why it is its own counter."""
    monkeypatch.setattr(settings, "daily_llm_token_budget_total", 1_000)
    throwaway = uuid4()
    async with db_session_maker() as session:
        session.add(User(id=throwaway))
        await session.commit()
        await record_usage(session, user_id=throwaway, input_tokens=900, output_tokens=100)
        # What Postgres does when the account goes (ON DELETE CASCADE); the
        # test database does not enforce foreign keys.
        await session.execute(delete(UserDailyUsage).where(UserDailyUsage.user_id == throwaway))
        await UserRepo(session).delete(throwaway)

    async with db_session_maker() as session:
        rows = (
            await session.scalars(select(UserDailyUsage).where(UserDailyUsage.user_id == throwaway))
        ).all()
        assert rows == []
        assert await UsageRepo(session).get_today_total() == 1_000
        over, retry_after = await check_budget(session, user_id=fake_user.id)
    assert over is True
    assert retry_after > 0
