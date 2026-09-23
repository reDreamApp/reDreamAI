"""Auth routes.

Supabase owns sign-in / sign-up / password reset. These routes only validate
an inbound JWT and proxy Supabase's password-reset email.
"""

from __future__ import annotations

import logging

import httpx
from fastapi import APIRouter, status

from ....core.config import settings
from ....core.dependencies import CurrentUser
from .schemas import PasswordResetRequest, PasswordResetResponse

log = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/session/validate", status_code=status.HTTP_204_NO_CONTENT)
async def validate_session(_: CurrentUser) -> None:
    """204 if the bearer token verifies; the dependency raises 401 otherwise."""
    return None


@router.post("/password-reset", response_model=PasswordResetResponse)
async def password_reset(req: PasswordResetRequest) -> PasswordResetResponse:
    """Trigger a Supabase password-reset email.

    `account_exists` is always True to avoid email enumeration; `email_sent`
    reflects whether Supabase accepted the request.
    """
    if not settings.supabase_url or not settings.supabase_service_role_key:
        log.warning("auth.password_reset.skipped reason=supabase_not_configured")
        return PasswordResetResponse(account_exists=True, email_sent=False)

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(
                f"{settings.supabase_url.rstrip('/')}/auth/v1/recover",
                headers={
                    "apikey": settings.supabase_service_role_key,
                    "Authorization": f"Bearer {settings.supabase_service_role_key}",
                    "Content-Type": "application/json",
                },
                json={"email": str(req.email)},
            )
        sent = r.status_code < 300
    except httpx.HTTPError:
        log.exception("auth.password_reset.failed")
        sent = False

    return PasswordResetResponse(account_exists=True, email_sent=sent)
