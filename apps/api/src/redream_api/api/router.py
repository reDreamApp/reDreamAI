"""Top-level router aggregator. Mounted by `main.py`."""

from __future__ import annotations

from fastapi import APIRouter

from .internal import moderation
from .v1 import (
    auth,
    chats,
    dreams,
    exports,
    health,
    help_center,
    profile,
    progress,
    reports,
    users,
)

router_v1 = APIRouter()
router_v1.include_router(health.router)
router_v1.include_router(auth.router)
router_v1.include_router(users.router)
router_v1.include_router(profile.router)
router_v1.include_router(dreams.router)
router_v1.include_router(chats.router)
router_v1.include_router(progress.router)
router_v1.include_router(reports.router)
router_v1.include_router(exports.router)
router_v1.include_router(help_center.router)


router_internal = APIRouter()
router_internal.include_router(moderation.router)
