"""UserDailyUsage — per-user per-day LLM token counter (ADR 0008)."""

from __future__ import annotations

from datetime import date
from uuid import UUID

from sqlalchemy import Date, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base


class UserDailyUsage(Base):
    __tablename__ = "user_daily_usage"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    usage_date: Mapped[date] = mapped_column(Date, primary_key=True, index=True)
    llm_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
