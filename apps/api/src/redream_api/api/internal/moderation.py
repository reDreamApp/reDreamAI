"""Expiring, single-use moderation capabilities. GET only confirms; POST mutates."""

from datetime import UTC, datetime
from hashlib import sha256
from html import escape
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.dependencies import get_db
from ...db.models.chat_message import ChatMessage
from ...db.models.content_report import ContentReport
from ...db.models.moderation_token import ModerationToken
from ...db.models.report_action import ReportAction
from ...services.email_notification import verify_action_signature

router = APIRouter(tags=["internal"])


def _verify(
    action: str, report_id: UUID, message_id: UUID | None, sig: str, expires: int, nonce: str
) -> None:
    if not verify_action_signature(
        action=action,
        report_id=report_id,
        message_id=message_id,
        signature=sig,
        expires=expires,
        nonce=nonce,
    ):
        raise HTTPException(403, "invalid or expired action link")


def _confirmation(
    action: str, report_id: UUID, message_id: UUID | None, sig: str, expires: int, nonce: str
) -> HTMLResponse:
    _verify(action, report_id, message_id, sig, expires, nonce)
    fields = {"sig": sig, "expires": str(expires), "nonce": nonce, "report_id": str(report_id)}
    inputs = "".join(
        f'<input type="hidden" name="{k}" value="{escape(v, quote=True)}">'
        for k, v in fields.items()
    )
    return HTMLResponse(
        (
            f"<!doctype html><title>Confirm moderation</title><h1>Confirm {action}</h1>"
            f'<p>Report {report_id}</p><form method="post" action="">{inputs}'
            f'<button type="submit">Confirm {action}</button></form>'
        ),
        headers={
            "Cache-Control": "no-store",
            "Referrer-Policy": "no-referrer",
            "Content-Security-Policy": (
                "default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"
            ),
        },
    )


async def _apply(
    db: AsyncSession,
    request: Request,
    action: str,
    report_id: UUID,
    message_id: UUID | None,
    sig: str,
    expires: int,
    nonce: str,
) -> dict[str, str]:
    _verify(action, report_id, message_id, sig, expires, nonce)
    report = await db.get(ContentReport, report_id)
    if report is None:
        raise HTTPException(404, "report not found")
    now = datetime.now(UTC)
    if action == "hide":
        if report.message_id != message_id:
            raise HTTPException(403, "message does not belong to report")
        message = await db.get(ChatMessage, message_id)
        if message is None:
            raise HTTPException(404, "message not found")
        message.visibility_status = "hidden"
        message.hidden_at = now
        message.hidden_reason = f"report {report_id}"
        message.hidden_by_report_id = report_id
        if report.status == "new":
            report.status = "triaged"
    else:
        report.status = {"resolve": "resolved", "reject": "rejected"}[action]
    report.updated_at = now
    await db.execute(delete(ModerationToken).where(ModerationToken.expires_at < now))
    db.add(
        ModerationToken(
            digest=sha256(nonce.encode()).hexdigest(),
            expires_at=datetime.fromtimestamp(expires, UTC),
        )
    )
    db.add(
        ReportAction(
            report_id=report_id,
            action=action,
            actor_type="email",
            note=f"message_id={message_id}" if message_id else None,
            actor_ip=request.client.host if request.client else None,
            actor_user_agent=request.headers.get("user-agent"),
        )
    )
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(409, "action link has already been used") from exc
    return {"status": "hidden" if action == "hide" else report.status}


@router.get("/reports/{report_id}/{action}")
async def confirm_report(
    report_id: UUID, action: Literal["resolve", "reject"], sig: str, expires: int, nonce: str
) -> HTMLResponse:
    return _confirmation(action, report_id, None, sig, expires, nonce)


@router.post("/reports/{report_id}/{action}")
async def act_report(
    report_id: UUID,
    action: Literal["resolve", "reject"],
    request: Request,
    sig: Annotated[str, Form()],
    expires: Annotated[int, Form()],
    nonce: Annotated[str, Form()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    return await _apply(db, request, action, report_id, None, sig, expires, nonce)


@router.get("/messages/{message_id}/hide")
async def confirm_hide(
    message_id: UUID, report_id: UUID, sig: str, expires: int, nonce: str
) -> HTMLResponse:
    return _confirmation("hide", report_id, message_id, sig, expires, nonce)


@router.post("/messages/{message_id}/hide")
async def act_hide(
    message_id: UUID,
    request: Request,
    report_id: Annotated[UUID, Form()],
    sig: Annotated[str, Form()],
    expires: Annotated[int, Form()],
    nonce: Annotated[str, Form()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    return await _apply(db, request, "hide", report_id, message_id, sig, expires, nonce)
