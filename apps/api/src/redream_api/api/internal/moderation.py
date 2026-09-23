"""Internal moderation actions reachable from signed email links (ADR 0006).

Auth model: a `sig` query parameter carrying the HMAC of the action body,
verified by `services.email_notification.verify_action_signature`.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.dependencies import Db
from ...db.models.content_report import ContentReport
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


async def _load_report(db: AsyncSession, report_id: UUID) -> ContentReport:
    report = await ContentReportRepo(db).get_by_id(report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "report not found")
    return report


async def _audit(
    db: AsyncSession,
    request: Request,
    *,
    report_id: UUID,
    action: str,
    note: str | None = None,
) -> None:
    await ReportActionRepo(db).create(
        ReportAction(
            report_id=report_id,
            action=action,
            actor_type="email",
            actor_ip=request.client.host if request.client else None,
            actor_user_agent=request.headers.get("user-agent"),
            note=note,
        )
    )


async def _set_report_status(
    db: AsyncSession,
    request: Request,
    *,
    report_id: UUID,
    sig: str,
    action: str,
    new_status: str,
) -> dict[str, str]:
    _check_sig(action, report_id, sig)
    report = await _load_report(db, report_id)
    await ContentReportRepo(db).set_status(report, new_status)
    await _audit(db, request, report_id=report.id, action=action)
    return {"status": new_status}


@router.get("/reports/{report_id}/resolve")
async def resolve_report(
    report_id: UUID, request: Request, db: Db, sig: Annotated[str, Query()]
) -> dict[str, str]:
    return await _set_report_status(
        db, request, report_id=report_id, sig=sig, action="resolve", new_status="resolved"
    )


@router.get("/reports/{report_id}/reject")
async def reject_report(
    report_id: UUID, request: Request, db: Db, sig: Annotated[str, Query()]
) -> dict[str, str]:
    return await _set_report_status(
        db, request, report_id=report_id, sig=sig, action="reject", new_status="rejected"
    )


@router.get("/messages/{message_id}/hide")
async def hide_message(
    message_id: UUID,
    request: Request,
    db: Db,
    sig: Annotated[str, Query()],
    report_id: Annotated[UUID, Query()],
) -> dict[str, str]:
    _check_sig("hide", report_id, sig, message_id=message_id)

    msg_repo = ChatMessageRepo(db)
    message = await msg_repo.get_by_id(message_id)
    if message is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "message not found")

    report_repo = ContentReportRepo(db)
    report = await _load_report(db, report_id)

    await msg_repo.hide(message, reason=f"report {report_id}", report_id=report_id)
    if report.status == "new":
        await report_repo.set_status(report, "triaged")

    await _audit(db, request, report_id=report.id, action="hide", note=f"message_id={message_id}")
    return {"status": "hidden"}
