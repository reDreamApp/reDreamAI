"""Moderation notifications via email + HMAC-signed action links (ADR 0006).

Notifications carry only metadata plus a signed link to the admin view —
content snapshots stay in Postgres.
"""

from __future__ import annotations

import hmac
import logging
from email.message import EmailMessage
from hashlib import sha256
from uuid import UUID

import aiosmtplib

from ..core.config import settings
from ..db.models.content_report import ContentReport

log = logging.getLogger(__name__)


def _sign(payload: str) -> str:
    secret = settings.report_notification_hmac_secret.encode()
    return hmac.new(secret, payload.encode(), sha256).hexdigest()


def _signed_action_url(action: str, report_id: UUID, message_id: UUID | None = None) -> str:
    """Build an HMAC-signed URL pointing at the internal moderation endpoint."""
    base = settings.report_action_base_url.rstrip("/")
    if action == "hide" and message_id is not None:
        path = f"/messages/{message_id}/hide"
        sig_body = f"hide:{message_id}:{report_id}"
        return f"{base}{path}?report_id={report_id}&sig={_sign(sig_body)}"
    path = f"/reports/{report_id}/{action}"
    sig_body = f"{action}:{report_id}"
    return f"{base}{path}?sig={_sign(sig_body)}"


def verify_action_signature(
    *, action: str, report_id: UUID, message_id: UUID | None, signature: str
) -> bool:
    if action == "hide" and message_id is not None:
        sig_body = f"hide:{message_id}:{report_id}"
    else:
        sig_body = f"{action}:{report_id}"
    expected = _sign(sig_body)
    return hmac.compare_digest(expected, signature)


def _format_email(report: ContentReport) -> EmailMessage:
    msg = EmailMessage()
    msg["Subject"] = (
        f"[reDreamAI] New {report.severity} report — {report.reason} ({report.target_role})"
    )
    msg["From"] = settings.report_notification_email_from
    msg["To"] = settings.report_notification_email

    resolve = _signed_action_url("resolve", report.id)
    reject = _signed_action_url("reject", report.id)
    hide = _signed_action_url("hide", report.id, report.message_id)

    body = f"""\
A new content report needs review.

Report ID:      {report.id}
Reason:         {report.reason}
Severity:       {report.severity}
Target role:    {report.target_role}
Chat ID:        {report.chat_id}
Message ID:     {report.message_id}
Stage:          {report.stage or "—"}
Language:       {report.language or "—"}
Created at:     {report.created_at.isoformat()}

Open the admin view to read content + context (snapshots stay on the server).

Actions (HMAC-signed):
- Resolve: {resolve}
- Reject:  {reject}
- Hide message: {hide}

— reDreamAI moderation pipeline
"""
    msg.set_content(body)
    return msg


async def send_report_notification(report: ContentReport) -> None:
    """Send an email notification for a new content report.

    No-op (with an info log) if the SMTP / email config is incomplete. This is
    intentional — the rest of the report pipeline (DB write, audit) must not
    fail because of email config issues.
    """

    if not settings.report_notification_email or not settings.report_notification_email_from:
        log.info("report.notification.skipped reason=email_not_configured report_id=%s", report.id)
        return
    if not settings.report_notification_hmac_secret:
        log.warning(
            "report.notification.skipped reason=hmac_secret_not_configured report_id=%s",
            report.id,
        )
        return
    if not settings.smtp_host:
        log.info("report.notification.skipped reason=smtp_not_configured report_id=%s", report.id)
        return

    msg = _format_email(report)
    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=settings.smtp_user or None,
            password=settings.smtp_password or None,
            start_tls=settings.smtp_use_tls,
        )
        log.info("report.notification.sent report_id=%s", report.id)
    except Exception:
        # Never block the request on an email failure.
        log.exception("report.notification.failed report_id=%s", report.id)
