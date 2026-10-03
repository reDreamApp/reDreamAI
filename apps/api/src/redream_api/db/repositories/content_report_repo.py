"""ContentReport repository."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.content_report import ContentReport


class ContentReportRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(self, report: ContentReport) -> ContentReport:
        self.db.add(report)
        await self.db.commit()
        await self.db.refresh(report)
        return report

    async def get_by_id(self, report_id: UUID) -> ContentReport | None:
        return await self.db.get(ContentReport, report_id)

    async def get_for_user_message(
        self, *, user_id: UUID, message_id: UUID
    ) -> ContentReport | None:
        stmt = select(ContentReport).where(
            ContentReport.user_id == user_id,
            ContentReport.message_id == message_id,
        )
        return (await self.db.scalars(stmt)).first()

    async def count_recent_for_user(
        self, user_id: UUID, *, window_minutes: int
    ) -> int:
        since = datetime.now(timezone.utc) - timedelta(minutes=window_minutes)
        stmt = (
            select(func.count(ContentReport.id))
            .where(
                ContentReport.user_id == user_id,
                ContentReport.created_at >= since,
            )
        )
        return int((await self.db.scalar(stmt)) or 0)

    async def set_status(
        self, report: ContentReport, status: str
    ) -> ContentReport:
        report.status = status
        report.updated_at = datetime.now(timezone.utc)
        await self.db.commit()
        await self.db.refresh(report)
        return report
