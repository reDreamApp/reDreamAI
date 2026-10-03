"""ReportAction repository — audit log."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from ..models.report_action import ReportAction


class ReportActionRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(self, action: ReportAction) -> ReportAction:
        self.db.add(action)
        await self.db.commit()
        await self.db.refresh(action)
        return action
