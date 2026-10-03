"""User account management — delete account, GDPR purge."""

from __future__ import annotations

from fastapi import APIRouter, status

from ....core.dependencies import CurrentUser, Db
from ....db.repositories.dream_repo import DreamRepo
from ....db.repositories.user_repo import UserRepo
from ....services.langfuse_service import delete_user_traces
from ....services.storage_service import delete_rehearsal_audio

router = APIRouter(prefix="/users", tags=["users"])


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(user: CurrentUser, db: Db) -> None:
    """Delete the user's row; cascades remove dreams, chats, etc.

    The Supabase `auth.users` row is separate infrastructure and is NOT deleted
    here — pair this with a Supabase admin call.
    """
    dream_ids = await _dream_ids(db, user)
    await UserRepo(db).delete_by_id(user.id)
    await delete_rehearsal_audio(dream_ids)
    await delete_user_traces(user.id)


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_data(user: CurrentUser, db: Db) -> None:
    """GDPR purge across Postgres + Storage + Langfuse.

    Storage and Langfuse are best-effort and logged independently — neither
    failure prevents the Postgres deletion.
    """
    dream_ids = await _dream_ids(db, user)
    await UserRepo(db).delete_by_id(user.id)
    await delete_rehearsal_audio(dream_ids)
    await delete_user_traces(user.id)


async def _dream_ids(db: Db, user: CurrentUser) -> list[int]:
    return [d.id for d in await DreamRepo(db).list_for_user(user.id, limit=10_000)]
