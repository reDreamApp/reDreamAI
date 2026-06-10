"""Chat routes — IRT-driven conversation with safety + budget gates.

Flow for `POST /chats/{id}/message`:
  1. Token-budget gate (ADR 0008) — 429 if exceeded.
  2. Persist user message.
  3. Call AI `/safety/classify` (ADR 0005). If risk=high: write safety_event,
     mark user message as flagged, return helpline payload, do NOT advance.
  4. Else: call AI `/chat` with the FULL history (stateless AI, ADR 0002).
  5. Persist AI message with `prompt_version`.
  6. Update `chat.current_stage` from the response. Set `is_done` if final.
  7. If stage is `summary`/`final` and structured fields are present, upsert a
     Dream row from the structured payload (replaces legacy `_parse_summary`,
     ADR 0003).
  8. Increment the user's daily token usage.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.dependencies import get_current_user, get_db
from ....db.models.chat_message import ChatMessage
from ....db.models.dream import Dream
from ....db.models.safety_event import SafetyEvent
from ....db.models.user import User
from ....db.repositories.chat_message_repo import ChatMessageRepo
from ....db.repositories.chat_repo import ChatRepo
from ....db.repositories.dream_repo import DreamRepo
from ....db.repositories.safety_event_repo import SafetyEventRepo
from ....services.ai_client import AIServiceError, BaseAiClient, get_ai_client
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

log = logging.getLogger(__name__)

router = APIRouter(prefix="/chats", tags=["chats"])

_HIDDEN_PLACEHOLDER = "[Message hidden by moderation]"


def _to_message_out(msg: ChatMessage) -> ChatMessageOut:
    content = (
        _HIDDEN_PLACEHOLDER if msg.visibility_status == "hidden" else msg.content
    )
    return ChatMessageOut(
        id=msg.id,
        role=msg.role,
        content=content,
        stage=msg.stage,
        visibility_status=msg.visibility_status,
        created_at=msg.created_at,
    )


def _to_chat_out(chat) -> ChatOut:
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


# ---------------------------------------------------------------------------


@router.post("/start", response_model=ChatStartResponse, status_code=status.HTTP_201_CREATED)
async def start_chat(
    body: ChatStartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChatStartResponse:
    chat = await ChatRepo(db).create(user_id=user.id, language=body.language)
    return ChatStartResponse(
        chat_id=chat.id, language=chat.language, current_stage=chat.current_stage
    )


@router.get("", response_model=list[ChatOut])
async def list_chats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ChatOut]:
    rows = await ChatRepo(db).list_for_user(user.id)
    return [_to_chat_out(c) for c in rows]


@router.get("/{chat_id}/messages", response_model=list[ChatMessageOut])
async def list_messages(
    chat_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ChatMessageOut]:
    chat = await ChatRepo(db).get_for_user(user.id, chat_id)
    if chat is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "chat not found")
    msgs = await ChatMessageRepo(db).list_for_chat(chat_id)
    return [_to_message_out(m) for m in msgs]


@router.delete("/{chat_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_chat(
    chat_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    repo = ChatRepo(db)
    chat = await repo.get_for_user(user.id, chat_id)
    if chat is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "chat not found")
    await repo.delete(chat)


# ---------------------------------------------------------------------------
# The interesting one.
# ---------------------------------------------------------------------------


@router.post("/{chat_id}/message", response_model=ChatMessageResponse)
async def send_message(
    chat_id: int,
    body: ChatMessageRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    ai: BaseAiClient = Depends(get_ai_client),
) -> ChatMessageResponse:
    chat_repo = ChatRepo(db)
    msg_repo = ChatMessageRepo(db)
    safety_repo = SafetyEventRepo(db)

    chat = await chat_repo.get_for_user(user.id, chat_id)
    if chat is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "chat not found")
    if chat.is_done:
        raise HTTPException(status.HTTP_409_CONFLICT, "chat is already finished")

    # ---- token budget (ADR 0008) -----------------------------------------
    over, retry_after = await check_budget(db, user_id=user.id)
    if over:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"daily token budget exceeded — resets in {retry_after}s",
            headers={"Retry-After": str(retry_after)},
        )

    # ---- persist user message --------------------------------------------
    user_msg = ChatMessage(
        chat_id=chat.id,
        role="user",
        content=body.content,
        stage=chat.current_stage,
    )
    await msg_repo.create(user_msg)

    # ---- safety classifier (ADR 0005) ------------------------------------
    try:
        safety = await ai.safety_classify(
            {"text": body.content, "language": chat.language}
        )
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"safety: {exc}") from exc

    if safety.get("risk") == "high":
        user_msg.safety_flagged = True
        await db.commit()
        await safety_repo.create(
            SafetyEvent(
                user_id=user.id,
                chat_id=chat.id,
                message_id=user_msg.id,
                risk="high",
                categories=list(safety.get("categories", [])),
                confidence=float(safety.get("confidence", 0.0)),
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
                risk="high",
                categories=list(safety.get("categories", [])),
                confidence=float(safety.get("confidence", 0.0)),
            ),
        )

    # ---- forward full history to AI /chat (stateless AI — ADR 0002) ------
    history_msgs = await msg_repo.list_for_chat(chat.id)
    payload = {
        "messages": [
            {
                "role": m.role,
                "content": m.content,
                "stage": m.stage,
                "language": chat.language,
            }
            for m in history_msgs
            if m.visibility_status == "visible"
        ],
        "language": chat.language,
        "session_id": str(chat.id),
    }

    try:
        ai_resp = await ai.chat(payload)
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"chat: {exc}") from exc

    ai_stage = str(ai_resp.get("stage", chat.current_stage))
    ai_text = str(ai_resp.get("response", ""))
    structured = ai_resp.get("structured")
    usage = ai_resp.get("usage", {}) or {}
    prompt_version = str(ai_resp.get("prompt_version", "unknown"))

    # ---- persist AI message ----------------------------------------------
    ai_msg = ChatMessage(
        chat_id=chat.id,
        role="assistant",
        content=ai_text,
        stage=ai_stage,
        prompt_version=prompt_version,
    )
    await msg_repo.create(ai_msg)

    # ---- advance chat state ----------------------------------------------
    chat.current_stage = ai_stage
    chat.is_done = ai_stage == "final"
    chat.updated_at = datetime.now(timezone.utc)
    await chat_repo.save(chat)

    # ---- structured-summary -> Dream (ADR 0003) --------------------------
    if structured and ai_stage in ("summary", "final"):
        await _upsert_dream_from_structured(
            db=db,
            user_id=user.id,
            chat_id=chat.id,
            language=chat.language,
            structured=structured,
        )

    # ---- token usage accounting (ADR 0008) -------------------------------
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
    user_id,
    chat_id: int,
    language: str,
    structured: dict,
) -> Dream:
    """Create or update the Dream row that corresponds to this chat's summary.

    `chat_id` (as a string) is used as `dream.session_id`; one chat → one dream.
    """
    repo = DreamRepo(db)
    session_key = str(chat_id)

    title = str(structured.get("title", "Untitled dream"))
    rewritten = str(structured.get("rewritten_summary") or structured.get("rewritten_dream", ""))
    original = str(
        structured.get("dream_summary")
        or structured.get("original_summary")
        or structured.get("original_dream", "")
    )

    existing = await repo.get_for_user_by_session(user_id, session_key)
    if existing is not None:
        existing.title = title
        existing.original_dream = original or existing.original_dream
        existing.rewritten_dream = rewritten or existing.rewritten_dream
        existing.last_edited = datetime.now(timezone.utc)
        # Rewritten changed → invalidate any cached rehearsal audio.
        existing.rehearsal_audio_url = None
        existing.rehearsal_script = None
        existing.rehearsal_duration = None
        existing.rehearsal_language = None
        existing.rehearsal_generated_at = None
        return await repo.save(existing)

    dream = Dream(
        user_id=user_id,
        title=title,
        original_dream=original,
        rewritten_dream=rewritten,
        is_nightmare=True,
        session_id=session_key,
        source="chatbot",
    )
    return await repo.create(dream)
