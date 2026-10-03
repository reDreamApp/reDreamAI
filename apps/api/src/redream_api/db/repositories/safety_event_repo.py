"""SafetyEvent repository (ADR 0005 — crisis detection audit trail)."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from ..models.safety_event import SafetyEvent


class SafetyEventRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(self, event: SafetyEvent) -> SafetyEvent:
        self.db.add(event)
        await self.db.commit()
        await self.db.refresh(event)
        return event
