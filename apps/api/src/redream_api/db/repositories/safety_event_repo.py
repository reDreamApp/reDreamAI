from __future__ import annotations

from ..models.safety_event import SafetyEvent
from .base import BaseRepo


class SafetyEventRepo(BaseRepo[SafetyEvent]):
    """Crisis-detection audit trail (ADR 0005)."""

    model = SafetyEvent
