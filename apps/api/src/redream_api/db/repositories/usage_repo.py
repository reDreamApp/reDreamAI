"""Per-user daily token counter (ADR 0008)."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select

from ...core.clock import today_utc
from ..models.user_daily_usage import UserDailyUsage
from .base import BaseRepo


class UsageRepo(BaseRepo[UserDailyUsage]):
    model = UserDailyUsage

    async def get_today(self, user_id: UUID) -> UserDailyUsage | None:
        stmt = select(UserDailyUsage).where(
            UserDailyUsage.user_id == user_id,
            UserDailyUsage.usage_date == today_utc(),
        )
        return (await self.db.scalars(stmt)).first()

    async def get_today_tokens(self, user_id: UUID) -> int:
        row = await self.get_today(user_id)
        return row.llm_tokens if row else 0

    async def increment_today(self, user_id: UUID, *, tokens: int) -> UserDailyUsage:
        row = await self.get_today(user_id)
        if row is None:
            return await self.create(
                UserDailyUsage(user_id=user_id, usage_date=today_utc(), llm_tokens=tokens)
            )
        row.llm_tokens += tokens
        return await self.save(row)
