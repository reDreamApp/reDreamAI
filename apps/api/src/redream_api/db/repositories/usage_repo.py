"""Usage repository — the token-budget counters (ADR 0008)."""

from __future__ import annotations

from datetime import UTC, datetime
from datetime import date as date_type
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.service_daily_usage import ServiceDailyUsage
from ..models.user_daily_usage import UserDailyUsage


def _today_utc() -> date_type:
    return datetime.now(UTC).date()


class UsageRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_today(self, user_id: UUID) -> UserDailyUsage | None:
        stmt = select(UserDailyUsage).where(
            UserDailyUsage.user_id == user_id,
            UserDailyUsage.usage_date == _today_utc(),
        )
        return (await self.db.scalars(stmt)).first()

    async def get_today_tokens(self, user_id: UUID) -> int:
        row = await self.get_today(user_id)
        return row.llm_tokens if row else 0

    async def get_today_total(self) -> int:
        """Tokens of all users today, including accounts deleted since."""
        stmt = select(ServiceDailyUsage.llm_tokens).where(
            ServiceDailyUsage.usage_date == _today_utc()
        )
        return (await self.db.scalar(stmt)) or 0

    async def _ensure_counters(self, user_id: UUID, day: date_type) -> None:
        # ON CONFLICT also handles simultaneous first requests of a UTC day.
        from sqlalchemy.dialects.postgresql import insert as pg_insert
        from sqlalchemy.dialects.sqlite import insert as sqlite_insert

        insert = sqlite_insert if self.db.get_bind().dialect.name == "sqlite" else pg_insert
        await self.db.execute(
            insert(ServiceDailyUsage).values(usage_date=day, llm_tokens=0).on_conflict_do_nothing()
        )
        await self.db.execute(
            insert(UserDailyUsage)
            .values(user_id=user_id, usage_date=day, llm_tokens=0)
            .on_conflict_do_nothing()
        )

    async def reserve(
        self, user_id: UUID, tokens: int, user_limit: int, total_limit: int
    ) -> date_type | None:
        day = _today_utc()
        await self._ensure_counters(user_id, day)
        total = await self.db.scalar(
            update(ServiceDailyUsage)
            .where(
                ServiceDailyUsage.usage_date == day,
                ServiceDailyUsage.llm_tokens + tokens <= total_limit,
            )
            .values(llm_tokens=ServiceDailyUsage.llm_tokens + tokens)
            .returning(ServiceDailyUsage.llm_tokens)
        )
        if total is None:
            await self.db.rollback()
            return None
        user = await self.db.scalar(
            update(UserDailyUsage)
            .where(
                UserDailyUsage.user_id == user_id,
                UserDailyUsage.usage_date == day,
                UserDailyUsage.llm_tokens + tokens <= user_limit,
            )
            .values(llm_tokens=UserDailyUsage.llm_tokens + tokens)
            .returning(UserDailyUsage.llm_tokens)
        )
        if user is None:
            await self.db.rollback()
            return None
        await self.db.commit()
        return day

    async def adjust(self, user_id: UUID, day: date_type, tokens: int) -> None:
        # Always lock/update the shared counter first, then the user counter.
        await self.db.execute(
            update(ServiceDailyUsage)
            .where(ServiceDailyUsage.usage_date == day)
            .values(llm_tokens=ServiceDailyUsage.llm_tokens + tokens)
        )
        await self.db.execute(
            update(UserDailyUsage)
            .where(UserDailyUsage.user_id == user_id, UserDailyUsage.usage_date == day)
            .values(llm_tokens=UserDailyUsage.llm_tokens + tokens)
        )
        await self.db.commit()

    async def increment_today(self, user_id: UUID, *, tokens: int) -> UserDailyUsage:
        day = _today_utc()
        await self._ensure_counters(user_id, day)
        await self.adjust(user_id, day, tokens)
        row = await self.get_today(user_id)
        assert row is not None
        await self.db.refresh(row)
        return row
