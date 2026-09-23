"""User account management — delete account, GDPR purge."""

from __future__ import annotations

from fastapi import APIRouter, status

from ....core.dependencies import CurrentUser, Db
from ....db.repositories.user_repo import UserRepo
from ....services.langfuse_service import delete_user_traces
from ....services.storage_service import delete_rehearsal_audio_for_user

router = APIRouter(prefix="/users", tags=["users"])


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(user: CurrentUser, db: Db) -> None:
    """Delete the user's row; cascades remove dreams, chats, etc.

    The Supabase `auth.users` row is separate infrastructure and is NOT deleted
    here — pair this with a Supabase admin call.
    """
    await UserRepo(db).delete_by_id(user.id)


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_data(user: CurrentUser, db: Db) -> None:
    """GDPR purge across Postgres + Storage + Langfuse.

    Storage and Langfuse are best-effort and logged independently — neither
    failure prevents the Postgres deletion.
    """
    await UserRepo(db).delete_by_id(user.id)
    await delete_rehearsal_audio_for_user(user.id)
    await delete_user_traces(user.id)
