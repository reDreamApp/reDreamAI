"""Help-center concerns — user support inquiries."""

from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.dependencies import get_current_user, get_db
from ....db.models.help_center_concern import HelpCenterConcern
from ....db.models.user import User
from ....db.repositories.help_center_concern_repo import HelpCenterConcernRepo
from .schemas import HelpCenterConcernIn, HelpCenterConcernOut

router = APIRouter(prefix="/help-center", tags=["help_center"])


@router.post("/concerns", response_model=HelpCenterConcernOut, status_code=status.HTTP_201_CREATED)
async def create_concern(
    body: HelpCenterConcernIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HelpCenterConcernOut:
    concern = HelpCenterConcern(
        user_id=user.id,
        email=str(body.email) if body.email else user.email,
        message=body.message,
    )
    saved = await HelpCenterConcernRepo(db).create(concern)
    return HelpCenterConcernOut(id=saved.id, created_at=saved.created_at)
