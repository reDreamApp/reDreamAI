"""ReportAction model — audit trail for moderation actions."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base
from ._types import PkBigInt


class ReportAction(Base):
    __tablename__ = "report_actions"

    id: Mapped[int] = mapped_column(PkBigInt, primary_key=True, autoincrement=True)
    report_id: Mapped[UUID] = mapped_column(
        ForeignKey("content_reports.id", ondelete="CASCADE"), nullable=False, index=True
    )
    action: Mapped[str] = mapped_column(String, nullable=False)
    # 'internal' = admin HTTP call; 'email' = HMAC-signed link click (ADR 0006).
    actor_type: Mapped[str] = mapped_column(String, nullable=False, default="internal")
    actor_id: Mapped[str | None] = mapped_column(String)
    note: Mapped[str | None] = mapped_column(String)
    actor_ip: Mapped[str | None] = mapped_column(String)
    actor_user_agent: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
