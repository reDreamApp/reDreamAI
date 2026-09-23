from __future__ import annotations

from uuid import UUID

from sqlalchemy import select

from ...core.clock import utcnow
from ..models.chat_message import ChatMessage
from .base import BaseRepo


class ChatMessageRepo(BaseRepo[ChatMessage]):
    model = ChatMessage

    async def list_for_chat(self, chat_id: int, *, limit: int = 500) -> list[ChatMessage]:
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat_id)
            .order_by(ChatMessage.created_at.asc())
            .limit(limit)
        )
        return list((await self.db.scalars(stmt)).all())

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
        message.visibility_status = "hidden"
        message.hidden_at = utcnow()
        message.hidden_reason = reason
        message.hidden_by_report_id = report_id
        return await self.save(message)
