"""Chat routes — IRT conversation with safety + budget gates.

`POST /chats/{id}/message` is the load-bearing one:
  1. Token-budget gate (ADR 0008) — 429 if exceeded.
  2. Persist the user message.
  3. Classify it (ADR 0005). risk=high short-circuits: record a safety event,
     flag the message, return the helpline payload, do NOT advance the stage.
  4. Otherwise forward the FULL history to the AI (stateless AI, ADR 0002),
     persist the reply, advance `chat.current_stage`.
  5. On summary/final with structured fields, upsert the Dream (ADR 0003).
  6. Record token usage.
"""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.clock import utcnow
from ....core.dependencies import CurrentUser, Db
from ....db.models.chat import Chat
from ....db.models.chat_message import ChatMessage
from ....db.models.dream import Dream
from ....db.models.safety_event import SafetyEvent
from ....db.models.user import User
from ....db.repositories.chat_message_repo import ChatMessageRepo
from ....db.repositories.chat_repo import ChatRepo
from ....db.repositories.dream_repo import DreamRepo
from ....db.repositories.safety_event_repo import SafetyEventRepo
from ....services.ai_client import Ai, AIServiceError
from ....services.token_budget import check_budget, record_usage
from .schemas import (
    ChatMessageOut,
    ChatMessageRequest,
    ChatMessageResponse,
    ChatOut,
    ChatStartRequest,
    ChatStartResponse,
    SafetyEventPayload,
)

router = APIRouter(prefix="/chats", tags=["chats"])

_HIDDEN_PLACEHOLDER = "[Message hidden by moderation]"


def _to_message_out(msg: ChatMessage) -> ChatMessageOut:
    return ChatMessageOut(
        id=msg.id,
        role=msg.role,
        content=_HIDDEN_PLACEHOLDER if msg.visibility_status == "hidden" else msg.content,
        stage=msg.stage,
        visibility_status=msg.visibility_status,
        created_at=msg.created_at,
    )


def _to_chat_out(chat: Chat) -> ChatOut:
    return ChatOut(
        id=chat.id,
        language=chat.language,
        current_stage=chat.current_stage,
        is_done=chat.is_done,
        is_nightmare=chat.is_nightmare,
        title=chat.title,
        created_at=chat.created_at,
        updated_at=chat.updated_at,
    )


async def _owned_chat(db: AsyncSession, user: User, chat_id: int) -> Chat:
    chat = await ChatRepo(db).get_for_user(user.id, chat_id)
    if chat is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "chat not found")
    return chat


@router.post("/start", response_model=ChatStartResponse, status_code=status.HTTP_201_CREATED)
async def start_chat(body: ChatStartRequest, user: CurrentUser, db: Db) -> ChatStartResponse:
    chat = await ChatRepo(db).create(Chat(user_id=user.id, language=body.language))
    return ChatStartResponse(
        chat_id=chat.id, language=chat.language, current_stage=chat.current_stage
    )


@router.get("", response_model=list[ChatOut])
async def list_chats(user: CurrentUser, db: Db) -> list[ChatOut]:
    return [_to_chat_out(c) for c in await ChatRepo(db).list_for_user(user.id)]


@router.get("/{chat_id}/messages", response_model=list[ChatMessageOut])
async def list_messages(chat_id: int, user: CurrentUser, db: Db) -> list[ChatMessageOut]:
    chat = await _owned_chat(db, user, chat_id)
    msgs = await ChatMessageRepo(db).list_for_chat(chat.id)
    return [_to_message_out(m) for m in msgs]


@router.delete("/{chat_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_chat(chat_id: int, user: CurrentUser, db: Db) -> None:
    chat = await _owned_chat(db, user, chat_id)
    await ChatRepo(db).delete(chat)


@router.post("/{chat_id}/message", response_model=ChatMessageResponse)
async def send_message(
    chat_id: int,
    body: ChatMessageRequest,
    user: CurrentUser,
    db: Db,
    ai: Ai,
) -> ChatMessageResponse:
    msg_repo = ChatMessageRepo(db)

    chat = await _owned_chat(db, user, chat_id)
    if chat.is_done:
        raise HTTPException(status.HTTP_409_CONFLICT, "chat is already finished")

    over, retry_after = await check_budget(db, user_id=user.id)
    if over:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"daily token budget exceeded — resets in {retry_after}s",
            headers={"Retry-After": str(retry_after)},
        )

    user_msg = await msg_repo.create(
        ChatMessage(
            chat_id=chat.id,
            role="user",
            content=body.content,
            stage=chat.current_stage,
        )
    )

    try:
        safety = await ai.safety_classify({"text": body.content, "language": chat.language})
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"safety: {exc}") from exc

    categories = list(safety.get("categories", []))
    confidence = float(safety.get("confidence", 0.0))

    if safety.get("risk") == "high":
        user_msg.safety_flagged = True
        await db.commit()
        await SafetyEventRepo(db).create(
            SafetyEvent(
                user_id=user.id,
                chat_id=chat.id,
                message_id=user_msg.id,
                risk="high",
                categories=categories,
                confidence=confidence,
                action_taken="helpline_shown",
                prompt_version=str(safety.get("prompt_version", "unknown")),
            )
        )
        return ChatMessageResponse(
            chat_id=chat.id,
            user_message=_to_message_out(user_msg),
            ai_message=None,
            stage=chat.current_stage,
            is_done=chat.is_done,
            safety_event=SafetyEventPayload(
                risk="high", categories=categories, confidence=confidence
            ),
        )

    history = await msg_repo.list_for_chat(chat.id)
    try:
        ai_resp = await ai.chat(
            {
                "messages": [
                    {
                        "role": m.role,
                        "content": m.content,
                        "stage": m.stage,
                        "language": chat.language,
                    }
                    for m in history
                    if m.visibility_status == "visible"
                ],
                "language": chat.language,
                "session_id": str(chat.id),
            }
        )
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"chat: {exc}") from exc

    ai_stage = str(ai_resp.get("stage", chat.current_stage))
    structured = ai_resp.get("structured")
    usage = ai_resp.get("usage") or {}

    ai_msg = await msg_repo.create(
        ChatMessage(
            chat_id=chat.id,
            role="assistant",
            content=str(ai_resp.get("response", "")),
            stage=ai_stage,
            prompt_version=str(ai_resp.get("prompt_version", "unknown")),
        )
    )

    chat.current_stage = ai_stage
    chat.is_done = ai_stage == "final"
    chat.updated_at = utcnow()
    if structured and structured.get("title"):
        chat.title = str(structured["title"])
    await ChatRepo(db).save(chat)

    if structured and ai_stage in ("summary", "final"):
        await _upsert_dream_from_structured(
            db=db,
            user_id=user.id,
            chat_id=chat.id,
            structured=structured,
        )

    await record_usage(
        db,
        user_id=user.id,
        input_tokens=int(usage.get("input_tokens", 0)),
        output_tokens=int(usage.get("output_tokens", 0)),
    )

    return ChatMessageResponse(
        chat_id=chat.id,
        user_message=_to_message_out(user_msg),
        ai_message=_to_message_out(ai_msg),
        stage=ai_stage,
        is_done=chat.is_done,
        safety_event=None,
    )


async def _upsert_dream_from_structured(
    *,
    db: AsyncSession,
    user_id: UUID,
    chat_id: int,
    structured: dict[str, object],
) -> Dream:
    """Create or update the Dream for this chat's summary — one chat, one dream,
    keyed by `dream.session_id == str(chat_id)` (ADR 0003)."""
    repo = DreamRepo(db)
    session_key = str(chat_id)

    title = str(structured.get("title", "Untitled dream"))
    rewritten = str(structured.get("rewritten_summary") or structured.get("rewritten_dream", ""))
    original = str(
        structured.get("dream_summary")
        or structured.get("original_summary")
        or structured.get("original_dream", "")
    )

    raw_intensity = structured.get("intensity")
    intensity = raw_intensity if isinstance(raw_intensity, int) else None

    existing = await repo.get_for_user_by_session(user_id, session_key)
    if existing is None:
        return await repo.create(
            Dream(
                user_id=user_id,
                title=title,
                original_dream=original,
                rewritten_dream=rewritten,
                intensity=intensity,
                is_nightmare=True,
                session_id=session_key,
                source="chatbot",
            )
        )

    existing.title = title
    existing.original_dream = original or existing.original_dream
    existing.rewritten_dream = rewritten or existing.rewritten_dream
    if intensity is not None:
        existing.intensity = intensity
    existing.last_edited = utcnow()
    existing.clear_rehearsal()
    return await repo.save(existing)
