"""Help-center concerns — user support inquiries."""

from __future__ import annotations

from fastapi import APIRouter, status

from ....core.dependencies import CurrentUser, Db
from ....db.models.help_center_concern import HelpCenterConcern
from ....db.repositories.help_center_concern_repo import HelpCenterConcernRepo
from .schemas import HelpCenterConcernIn, HelpCenterConcernOut

router = APIRouter(prefix="/help-center", tags=["help_center"])


@router.post("/concerns", response_model=HelpCenterConcernOut, status_code=status.HTTP_201_CREATED)
async def create_concern(
    body: HelpCenterConcernIn, user: CurrentUser, db: Db
) -> HelpCenterConcernOut:
    saved = await HelpCenterConcernRepo(db).create(
        HelpCenterConcern(
            user_id=user.id,
            email=str(body.email) if body.email else user.email,
            message=body.message,
        )
    )
    return HelpCenterConcernOut(id=saved.id, created_at=saved.created_at)
