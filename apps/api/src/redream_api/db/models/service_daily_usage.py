"""ServiceDailyUsage — LLM tokens of all users per day (ADR 0008)."""

from __future__ import annotations

from datetime import date

from sqlalchemy import BigInteger, Date
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base


class ServiceDailyUsage(Base):
    """One row per UTC day. Not tied to users, so it keeps what deleted
    accounts used."""

    __tablename__ = "service_daily_usage"

    usage_date: Mapped[date] = mapped_column(Date, primary_key=True)
    llm_tokens: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
