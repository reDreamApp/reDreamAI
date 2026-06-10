"""Help-center schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class HelpCenterConcernIn(BaseModel):
    email: EmailStr | None = None
    message: str = Field(min_length=1, max_length=10_000)


class HelpCenterConcernOut(BaseModel):
    id: int
    created_at: datetime
