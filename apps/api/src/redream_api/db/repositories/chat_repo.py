from __future__ import annotations

from uuid import UUID

from sqlalchemy import select

from ..models.chat import Chat
from .base import BaseRepo


class ChatRepo(BaseRepo[Chat]):
    model = Chat

    async def list_for_user(self, user_id: UUID, *, limit: int = 200) -> list[Chat]:
        stmt = (
            select(Chat)
            .where(Chat.user_id == user_id)
            .order_by(Chat.created_at.desc())
            .limit(limit)
        )
        return list((await self.db.scalars(stmt)).all())

    async def get_for_user(self, user_id: UUID, chat_id: int) -> Chat | None:
        stmt = select(Chat).where(Chat.id == chat_id, Chat.user_id == user_id)
        return (await self.db.scalars(stmt)).first()
