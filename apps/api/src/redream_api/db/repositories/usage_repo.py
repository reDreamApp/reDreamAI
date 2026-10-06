"""Usage repository — the token-budget counters (ADR 0008)."""

from __future__ import annotations

from datetime import date as date_type, datetime, timezone
from typing import Any, cast
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.service_daily_usage import ServiceDailyUsage
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

    async def get_today_total(self) -> int:
        """Tokens of all users today, including accounts deleted since."""
        stmt = select(ServiceDailyUsage.llm_tokens).where(
            ServiceDailyUsage.usage_date == _today_utc()
        )
        return (await self.db.scalar(stmt)) or 0

    async def _add_to_total(self, tokens: int) -> None:
        """Add to the day's service-wide counter; the caller commits."""
        today = _today_utc()
        # In SQL, so requests of different users cannot overwrite each other.
        add = (
            update(ServiceDailyUsage)
            .where(ServiceDailyUsage.usage_date == today)
            .values(llm_tokens=ServiceDailyUsage.llm_tokens + tokens)
        )
        result = cast("CursorResult[Any]", await self.db.execute(add))
        if result.rowcount:
            return
        try:
            async with self.db.begin_nested():
                self.db.add(ServiceDailyUsage(usage_date=today, llm_tokens=tokens))
        except IntegrityError:
            # Another request created the day's row in the meantime.
            await self.db.execute(add)

    async def increment_today(self, user_id: UUID, *, tokens: int) -> UserDailyUsage:
        """Count tokens for the user and for the service as a whole."""
        await self._add_to_total(tokens)
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
