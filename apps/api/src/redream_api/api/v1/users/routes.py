"""User account management — delete account, GDPR purge, Art. 9 consent."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.config import settings
from ....core.dependencies import get_current_user, get_db
from ....db.models.user import User
from ....db.repositories.consent_repo import ConsentRepo
from ....db.repositories.user_repo import UserRepo
from ....services.langfuse_service import delete_user_traces
from ....services.storage_service import delete_rehearsal_audio_for_user

log = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])


class ConsentStatusOut(BaseModel):
    required_version: str
    granted_version: str | None
    consent_required: bool
    """True when the app must show the consent screen before any health-data
    feature: no grant yet, withdrawn, or the consent text changed."""


class ConsentGrantRequest(BaseModel):
    version: str
    """The consent-text version the user actually saw — must match the
    current required version (a stale screen must not record a grant)."""


@router.get("/me/consent", response_model=ConsentStatusOut)
async def get_consent(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ConsentStatusOut:
    latest = await ConsentRepo(db).latest(user.id)
    granted_version = latest.version if latest is not None and latest.granted else None
    return ConsentStatusOut(
        required_version=settings.consent_version,
        granted_version=granted_version,
        consent_required=granted_version != settings.consent_version,
    )


@router.post("/me/consent", status_code=status.HTTP_204_NO_CONTENT)
async def grant_consent(
    body: ConsentGrantRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Records explicit consent (Art. 9(2)(a)) as an append-only proof row."""
    if body.version != settings.consent_version:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "consent text changed — reload the consent screen",
        )
    await ConsentRepo(db).record(user.id, version=body.version, granted=True)


@router.delete("/me/consent", status_code=status.HTTP_204_NO_CONTENT)
async def withdraw_consent(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Withdrawal — as easy as granting (Art. 7(3)). Data stays until the
    user deletes it; health-data features gate until re-consent."""
    await ConsentRepo(db).record(
        user.id, version=settings.consent_version, granted=False
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete the user's account row. Cascades remove dreams, chats, etc.

    The Supabase `auth.users` row is NOT deleted here — it's separate
    infrastructure. Recommend pairing with a Supabase admin call.
    """
    await UserRepo(db).delete(user.id)


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_data(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """GDPR purge: delete this user's data across Postgres + Storage + Langfuse.

    All three are best-effort and logged independently — a Storage or Langfuse
    failure does not prevent the Postgres deletion.
    """
    user_id = user.id
    await UserRepo(db).delete(user_id)
    await delete_rehearsal_audio_for_user(user_id)
    await delete_user_traces(user_id)
