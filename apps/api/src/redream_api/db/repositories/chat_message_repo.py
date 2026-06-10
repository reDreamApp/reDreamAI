"""ChatMessage repository."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.chat_message import ChatMessage


class ChatMessageRepo:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_for_chat(self, chat_id: int, *, limit: int = 500) -> list[ChatMessage]:
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id)
            .order_by(ChatMessage.created_at.asc())
            .limit(limit)
        )
        return list((await self.db.scalars(stmt)).all())

    async def get_by_id(self, message_id: UUID) -> ChatMessage | None:
        return await self.db.get(ChatMessage, message_id)

    async def create(self, message: ChatMessage) -> ChatMessage:
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def get_latest_summary(self, chat_id: int) -> ChatMessage | None:
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id, ChatMessage.stage == "summary")
            .order_by(ChatMessage.created_at.desc())
            .limit(1)
        )
        return (await self.db.scalars(stmt)).first()

    async def hide(
        self,
        message: ChatMessage,
        *,
        reason: str,
        report_id: UUID | None,
    ) -> ChatMessage:
        from datetime import datetime, timezone

        message.visibility_status = "hidden"
        message.hidden_at = datetime.now(timezone.utc)
        message.hidden_reason = reason
        message.hidden_by_report_id = report_id
        await self.db.commit()
        await self.db.refresh(message)
        return message
