from __future__ import annotations

from ..models.report_action import ReportAction
from .base import BaseRepo


class ReportActionRepo(BaseRepo[ReportAction]):
    """Moderation audit log."""

    model = ReportAction
