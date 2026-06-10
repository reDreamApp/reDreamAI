"""Reports schemas."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ContentReportCreate(BaseModel):
    chat_id: int
    message_id: UUID
    target_role: str = Field(pattern="^(assistant|user)$")
    reason: str = Field(
        pattern="^(child_safety|self_harm|sexual|hate|violence|harassment|deceptive|other)$"
    )
    details: str | None = None


class ContentReportResponse(BaseModel):
    id: UUID
    status: str
    severity: str
    created_at: datetime
