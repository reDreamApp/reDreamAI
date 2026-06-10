"""Content reports — rate-limited, fire email notification (ADR 0006)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ....core.config import settings
from ....core.dependencies import get_current_user, get_db
from ....db.models.content_report import ContentReport
from ....db.models.user import User
from ....db.repositories.chat_message_repo import ChatMessageRepo
from ....db.repositories.chat_repo import ChatRepo
from ....db.repositories.content_report_repo import ContentReportRepo
from ....services.email_notification import send_report_notification
from .schemas import ContentReportCreate, ContentReportResponse

router = APIRouter(prefix="/reports", tags=["reports"])

_REASON_SEVERITY: dict[str, str] = {
    "child_safety": "high",
    "self_harm": "high",
    "sexual": "high",
    "hate": "high",
    "violence": "medium",
    "harassment": "medium",
    "deceptive": "medium",
    "other": "low",
}


@router.post("/ai-content", response_model=ContentReportResponse, status_code=status.HTTP_201_CREATED)
async def create_report(
    body: ContentReportCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ContentReportResponse:
    repo = ContentReportRepo(db)

    # Rate limit per user.
    recent = await repo.count_recent_for_user(
        user.id, window_minutes=settings.report_rate_limit_window_minutes
    )
    if recent >= settings.report_rate_limit_count:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"too many reports — limit {settings.report_rate_limit_count} per "
            f"{settings.report_rate_limit_window_minutes} minutes",
        )

    chat = await ChatRepo(db).get_for_user(user.id, body.chat_id)
    if chat is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "chat not found")

    msg = await ChatMessageRepo(db).get_by_id(body.message_id)
    if msg is None or msg.chat_id != chat.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "message not found in chat")
    if msg.role != body.target_role:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"target_role={body.target_role} does not match the message's role={msg.role}",
        )

    # Context snapshot — N before, N after.
    all_messages = await ChatMessageRepo(db).list_for_chat(chat.id, limit=10_000)
    idx = next((i for i, m in enumerate(all_messages) if m.id == msg.id), -1)
    before = max(0, idx - settings.report_context_before)
    after = min(len(all_messages), idx + 1 + settings.report_context_after)
    context = [
        {"role": m.role, "stage": m.stage, "content": m.content}
        for m in all_messages[before:after]
    ]

    severity = _REASON_SEVERITY.get(body.reason, "low")

    report = ContentReport(
        user_id=user.id,
        chat_id=chat.id,
        message_id=msg.id,
        target_role=body.target_role,
        reason=body.reason,
        details=body.details,
        severity=severity,
        content_snapshot=msg.content,
        context_snapshot=context,
        stage=msg.stage,
        language=chat.language,
    )
    created = await repo.create(report)

    # Side effect: email + HMAC links (no PII in body, no Telegram).
    await send_report_notification(created)

    return ContentReportResponse(
        id=created.id,
        status=created.status,
        severity=created.severity,
        created_at=created.created_at,
    )
