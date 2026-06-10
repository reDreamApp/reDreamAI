"""Internal moderation actions reachable from email links (ADR 0006).

Auth model: a `sig` query parameter carrying the HMAC of the action body,
verified by `services.email_notification.verify_action_signature`. There is
no Telegram webhook (legacy `/internal/telegram/webhook` is gone — ADR 0006).
"""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.dependencies import get_db
from ...db.models.report_action import ReportAction
from ...db.repositories.chat_message_repo import ChatMessageRepo
from ...db.repositories.content_report_repo import ContentReportRepo
from ...db.repositories.report_action_repo import ReportActionRepo
from ...services.email_notification import verify_action_signature

router = APIRouter(tags=["internal"])


def _check_sig(action: str, report_id: UUID, sig: str, message_id: UUID | None = None) -> None:
    if not verify_action_signature(
        action=action, report_id=report_id, message_id=message_id, signature=sig
    ):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "invalid signature")


def _audit(req: Request, action: str) -> ReportAction:
    return ReportAction(
        report_id=UUID(int=0),  # placeholder, replaced before commit
        action=action,
        actor_type="email",
        actor_ip=req.client.host if req.client else None,
        actor_user_agent=req.headers.get("user-agent"),
    )


@router.get("/reports/{report_id}/resolve")
async def resolve_report(
    report_id: UUID,
    request: Request,
    sig: str = Query(...),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    _check_sig("resolve", report_id, sig)
    repo = ContentReportRepo(db)
    report = await repo.get_by_id(report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "report not found")
    await repo.set_status(report, "resolved")

    audit = _audit(request, "resolve")
    audit.report_id = report.id
    await ReportActionRepo(db).create(audit)
    return {"status": "resolved"}


@router.get("/reports/{report_id}/reject")
async def reject_report(
    report_id: UUID,
    request: Request,
    sig: str = Query(...),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    _check_sig("reject", report_id, sig)
    repo = ContentReportRepo(db)
    report = await repo.get_by_id(report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "report not found")
    await repo.set_status(report, "rejected")

    audit = _audit(request, "reject")
    audit.report_id = report.id
    await ReportActionRepo(db).create(audit)
    return {"status": "rejected"}


@router.get("/messages/{message_id}/hide")
async def hide_message(
    message_id: UUID,
    request: Request,
    sig: str = Query(...),
    report_id: UUID = Query(...),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    _check_sig("hide", report_id, sig, message_id=message_id)

    msg_repo = ChatMessageRepo(db)
    message = await msg_repo.get_by_id(message_id)
    if message is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "message not found")

    report_repo = ContentReportRepo(db)
    report = await report_repo.get_by_id(report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "report not found")

    await msg_repo.hide(message, reason=f"report {report_id}", report_id=report_id)
    if report.status == "new":
        await report_repo.set_status(report, "triaged")

    audit = _audit(request, "hide")
    audit.report_id = report.id
    audit.note = f"message_id={message_id}"
    await ReportActionRepo(db).create(audit)
    return {"status": "hidden"}
