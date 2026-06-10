"""SafetyEvent model — crisis-detection audit trail (ADR 0005)."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger, DateTime, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base
from ._types import StringArrayCol


class SafetyEvent(Base):
    __tablename__ = "safety_events"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    chat_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("chats.id", ondelete="SET NULL")
    )
    message_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("chat_messages.id", ondelete="SET NULL")
    )

    risk: Mapped[str] = mapped_column(String, nullable=False, index=True)
    categories: Mapped[list[str]] = mapped_column(StringArrayCol, nullable=False, default=list)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    action_taken: Mapped[str] = mapped_column(
        String, nullable=False, default="helpline_shown"
    )
    prompt_version: Mapped[str] = mapped_column(String, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
