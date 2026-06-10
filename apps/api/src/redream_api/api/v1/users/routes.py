"""User account management — delete account, GDPR purge."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.dependencies import get_current_user, get_db
from ....db.models.user import User
from ....db.repositories.user_repo import UserRepo
from ....services.langfuse_service import delete_user_traces
from ....services.storage_service import delete_rehearsal_audio_for_user

log = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])


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
