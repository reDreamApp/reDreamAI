from __future__ import annotations

from ..models.help_center_concern import HelpCenterConcern
from .base import BaseRepo


class HelpCenterConcernRepo(BaseRepo[HelpCenterConcern]):
    model = HelpCenterConcern
