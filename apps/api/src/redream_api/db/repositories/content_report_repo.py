from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from sqlalchemy import func, select

from ...core.clock import utcnow
from ..models.content_report import ContentReport
from .base import BaseRepo


class ContentReportRepo(BaseRepo[ContentReport]):
    model = ContentReport

    async def get_for_user_message(
        self, *, user_id: UUID, message_id: UUID
    ) -> ContentReport | None:
        stmt = select(ContentReport).where(
            ContentReport.user_id == user_id,
            ContentReport.message_id == message_id,
        )
        return (await self.db.scalars(stmt)).first()

    async def count_recent_for_user(self, user_id: UUID, *, window_minutes: int) -> int:
        since = utcnow() - timedelta(minutes=window_minutes)
        stmt = select(func.count(ContentReport.id)).where(
            ContentReport.user_id == user_id,
            ContentReport.created_at >= since,
        )
        return int((await self.db.scalar(stmt)) or 0)

    async def set_status(self, report: ContentReport, status: str) -> ContentReport:
        report.status = status
        report.updated_at = utcnow()
        return await self.save(report)
