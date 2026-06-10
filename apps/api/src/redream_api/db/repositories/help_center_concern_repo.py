"""HelpCenterConcern repository."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from ..models.help_center_concern import HelpCenterConcern


class HelpCenterConcernRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(self, concern: HelpCenterConcern) -> HelpCenterConcern:
        self.db.add(concern)
        await self.db.commit()
        await self.db.refresh(concern)
        return concern
