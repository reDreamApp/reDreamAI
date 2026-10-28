"""Daily LLM token budget gate (ADR 0008)."""

from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import delete, select

from redream_api.core.config import settings
from redream_api.db.models.service_daily_usage import ServiceDailyUsage
from redream_api.db.models.user import User
from redream_api.db.models.user_daily_usage import UserDailyUsage
from redream_api.db.repositories import usage_repo
from redream_api.db.repositories.usage_repo import UsageRepo
from redream_api.db.repositories.user_repo import UserRepo
from redream_api.services.token_budget import check_budget, record_usage

from .conftest import FakeAiClient, seed_usage, start_chat


async def _seed_total(db_session_maker, tokens: int) -> None:
    async with db_session_maker() as session:
        session.add(ServiceDailyUsage(usage_date=datetime.now(UTC).date(), llm_tokens=tokens))
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


def test_the_total_limits_default_to_1m_a_day_and_10m_a_month() -> None:
    assert settings.daily_llm_token_budget_total == 1_000_000
    assert settings.monthly_llm_token_budget_total == 10_000_000


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


async def test_chat_rejected_without_room_for_reservation(
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
    assert r.status_code == 429

    async with db_session_maker() as session:
        total = await UsageRepo(session).get_today_total()
    assert total == settings.daily_llm_token_budget_total - 1


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


# ---------------------------------------------------------------------------
# What happens to a reservation when the turn does not complete
# ---------------------------------------------------------------------------


async def _used(db_session_maker, user_id) -> tuple[int, int]:
    async with db_session_maker() as session:
        repo = UsageRepo(session)
        return await repo.get_today_tokens(user_id), await repo.get_today_total()


async def test_a_failed_chat_turn_gives_its_reservation_back(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    from redream_api.services.ai_client import AIServiceError

    chat_id = await start_chat(client)
    fake_ai.queue_chat_error(AIServiceError("provider down"))

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "hello"})

    assert r.status_code == 502
    assert await _used(db_session_maker, fake_user.id) == (0, 0)


async def test_an_outage_does_not_use_up_the_day(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    """Twenty failed turns would have kept 160k+ under the old rule: more than
    one user's whole day, and a third of everyone's."""
    from redream_api.services.ai_client import AIServiceError

    chat_id = await start_chat(client)
    for _ in range(20):
        fake_ai.queue_chat_error(AIServiceError("provider down"))
        r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "hello"})
        assert r.status_code == 502

    assert await _used(db_session_maker, fake_user.id) == (0, 0)
    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more.",
            "structured": None,
            "usage": {"input_tokens": 30, "output_tokens": 50},
            "prompt_version": "chat-v0",
        }
    )
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "hello"})
    assert r.status_code == 200
    assert await _used(db_session_maker, fake_user.id) == (80, 80)


async def test_a_failed_stream_gives_its_reservation_back(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    import json

    chat_id = await start_chat(client)
    fake_ai.queue_chat_stream(
        ["data: " + json.dumps({"content": "part"}), "data: " + json.dumps({"error": "upstream"})]
    )

    r = await client.post(f"/api/v1/chats/{chat_id}/message/stream", json={"content": "hi"})

    assert '"error"' in r.text
    assert await _used(db_session_maker, fake_user.id) == (0, 0)


async def test_a_high_risk_message_reserves_nothing(
    client, fake_ai: FakeAiClient, fake_user, db_session_maker
) -> None:
    chat_id = await start_chat(client)
    fake_ai.queue_safety(
        {
            "risk": "high",
            "categories": ["self_harm"],
            "confidence": 0.93,
            "prompt_version": "safety-v0.3.0",
        }
    )

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "..."})

    assert r.status_code == 200
    assert r.json()["safety_event"]["risk"] == "high"
    assert await _used(db_session_maker, fake_user.id) == (0, 0)


async def test_a_turn_the_client_abandons_keeps_its_reservation(
    db, fake_user, fake_ai: FakeAiClient, db_session_maker
) -> None:
    """Cancelling must not be a way around the limits."""
    import json

    from redream_api.api.v1.chats import routes as chats_routes
    from redream_api.api.v1.chats.schemas import ChatMessageRequest
    from redream_api.db.repositories.chat_repo import ChatRepo

    fake_ai.queue_chat_stream(
        ["data: " + json.dumps({"content": "You turn "}), "data: " + json.dumps({"content": "x"})]
    )
    chat = await ChatRepo(db).create(user_id=fake_user.id)
    setup = await chats_routes._pre_turn(
        chat.id, ChatMessageRequest(content="hi"), fake_user, db, fake_ai
    )
    gen = chats_routes._stream_ai_turn(db, fake_ai, fake_user, setup)
    await gen.__anext__()
    await gen.__anext__()
    await gen.aclose()  # the client went away mid-stream

    user, total = await _used(db_session_maker, fake_user.id)
    assert user == total == setup.reservation.tokens
    assert user >= 8192


# ---------------------------------------------------------------------------
# The monthly limit of all users together (ADR 0008, amended 2026-10-28)
# ---------------------------------------------------------------------------

_MID_MONTH = date(2026, 10, 15)


async def _seed_days(db_session_maker, rows: dict[date, int]) -> None:
    async with db_session_maker() as session:
        for day, tokens in rows.items():
            session.add(ServiceDailyUsage(usage_date=day, llm_tokens=tokens))
        await session.commit()


async def test_the_month_counts_earlier_days_but_not_last_month(
    fake_user, db_session_maker, monkeypatch
) -> None:
    monkeypatch.setattr(usage_repo, "_today_utc", lambda: _MID_MONTH)
    await _seed_days(db_session_maker, {date(2026, 10, 1): 40_000, date(2026, 9, 30): 9_000_000})
    async with db_session_maker() as session:
        repo = UsageRepo(session)
        assert await repo.reserve(fake_user.id, 8192, 100_000, 1_000_000, 50_000) == _MID_MONTH
        assert await repo.get_month_total() == 48_192
        # 40,000 earlier + 8,192 today + 8,192 more would pass 50,000.
        assert await repo.reserve(fake_user.id, 8192, 100_000, 1_000_000, 50_000) is None
        assert await repo.get_month_total() == 48_192


async def test_429_for_everyone_when_the_month_is_used_up(
    client, fake_user, db_session_maker, monkeypatch
) -> None:
    chat_id = await start_chat(client)
    monkeypatch.setattr(usage_repo, "_today_utc", lambda: _MID_MONTH)
    monkeypatch.setattr(settings, "monthly_llm_token_budget_total", 50_000)
    await _seed_days(db_session_maker, {date(2026, 10, 1): 50_000})

    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "anything"})
    assert r.status_code == 429
    assert "monthly" in r.json()["detail"]
    assert int(r.headers["Retry-After"]) > 0

    async with db_session_maker() as session:
        over, retry_after = await check_budget(session, user_id=fake_user.id)
    assert over and retry_after > 0
