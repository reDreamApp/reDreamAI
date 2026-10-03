"""UserDailyUsage repository — token-budget counter (ADR 0008)."""

from __future__ import annotations

from datetime import date as date_type, datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.user_daily_usage import UserDailyUsage


def _today_utc() -> date_type:
    return datetime.now(timezone.utc).date()


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

    async def increment_today(self, user_id: UUID, *, tokens: int) -> UserDailyUsage:
        row = await self.get_today(user_id)
        if row is None:
            row = UserDailyUsage(
                user_id=user_id, usage_date=_today_utc(), llm_tokens=tokens
            )
            self.db.add(row)
        else:
            row.llm_tokens += tokens
        await self.db.commit()
        await self.db.refresh(row)
        return row
