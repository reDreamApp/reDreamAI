"""Consumed moderation capabilities; shared by every API worker."""

from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base


class ModerationToken(Base):
    __tablename__ = "moderation_tokens"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
