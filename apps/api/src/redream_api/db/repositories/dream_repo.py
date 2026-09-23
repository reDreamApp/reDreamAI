from __future__ import annotations

from uuid import UUID

from sqlalchemy import select, update

from ..models.dream import Dream
from .base import BaseRepo


class DreamRepo(BaseRepo[Dream]):
    model = Dream

    async def list_for_user(self, user_id: UUID, *, limit: int = 200) -> list[Dream]:
        stmt = (
            select(Dream)
            .where(Dream.user_id == user_id)
            .order_by(Dream.created_at.desc())
            .limit(limit)
        )
        return list((await self.db.scalars(stmt)).all())

    async def get_for_user(self, user_id: UUID, dream_id: int) -> Dream | None:
        stmt = select(Dream).where(Dream.id == dream_id, Dream.user_id == user_id)
        return (await self.db.scalars(stmt)).first()

    async def get_for_user_by_session(self, user_id: UUID, session_id: str) -> Dream | None:
        stmt = select(Dream).where(Dream.user_id == user_id, Dream.session_id == session_id)
        return (await self.db.scalars(stmt)).first()

    async def clear_current_for_user(self, user_id: UUID) -> None:
        """Unset `is_current_dream` on every dream — call before setting a new one."""
        await self.db.execute(
            update(Dream).where(Dream.user_id == user_id).values(is_current_dream=False)
        )
        await self.db.commit()
