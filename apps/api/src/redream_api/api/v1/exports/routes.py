"""Data export — single JSON dump of the user's profile + chats + dreams."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter

from ....core.dependencies import CurrentUser, Db
from ....db.models.chat_message import ChatMessage
from ....db.models.dream import Dream
from ....db.repositories.chat_message_repo import ChatMessageRepo
from ....db.repositories.chat_repo import ChatRepo
from ....db.repositories.dream_repo import DreamRepo

router = APIRouter(prefix="/exports", tags=["exports"])

_ALL = 10_000


def _message_json(m: ChatMessage) -> dict[str, Any]:
    return {
        "id": str(m.id),
        "role": m.role,
        "stage": m.stage,
        "content": m.content if m.visibility_status == "visible" else "[hidden]",
        "created_at": m.created_at.isoformat(),
    }


def _dream_json(d: Dream) -> dict[str, Any]:
    return {
        "id": d.id,
        "title": d.title,
        "original_dream": d.original_dream,
        "rewritten_dream": d.rewritten_dream,
        "intensity": d.intensity,
        "is_nightmare": d.is_nightmare,
        "source": d.source,
        "created_at": d.created_at.isoformat(),
        "practice_timestamps": list(d.practice_timestamps or []),
    }


@router.get("/data")
async def export_data(user: CurrentUser, db: Db) -> dict[str, Any]:
    chats = await ChatRepo(db).list_for_user(user.id, limit=_ALL)
    dreams = await DreamRepo(db).list_for_user(user.id, limit=_ALL)
    msg_repo = ChatMessageRepo(db)

    return {
        "user": {
            "id": str(user.id),
            "email": user.email,
            "gender": user.gender,
            "age_range": user.age_range,
            "nightmare_frequency": user.nightmare_frequency,
            "created_at": user.created_at.isoformat(),
        },
        "dreams": [_dream_json(d) for d in dreams],
        "chats": [
            {
                "id": c.id,
                "language": c.language,
                "current_stage": c.current_stage,
                "is_done": c.is_done,
                "created_at": c.created_at.isoformat(),
                "messages": [
                    _message_json(m) for m in await msg_repo.list_for_chat(c.id, limit=_ALL)
                ],
            }
            for c in chats
        ],
    }
