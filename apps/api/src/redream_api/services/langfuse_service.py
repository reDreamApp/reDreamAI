"""Langfuse helpers — used by the GDPR purge path (ADR 0007).

Replaces the legacy `langfuse_service.delete_langfuse_user_data` no-op stub.
This implementation is best-effort: it tries the Langfuse SDK delete API and
logs the outcome. The GDPR purge does not fail if Langfuse is unreachable —
the user-facing deletion is Postgres-bound (also best-effort for Storage).
"""

from __future__ import annotations

import logging
from uuid import UUID

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)


async def delete_user_traces(user_id: UUID) -> bool:
    """Delete the user's traces from self-hosted Langfuse.

    Returns True on success, False if Langfuse is not configured / unreachable.
    """
    if not settings.langfuse_host or not settings.langfuse_public_key:
        log.warning(
            "langfuse.delete.skipped reason=not_configured user_id=%s", user_id
        )
        return False

    # Langfuse v2 trace-delete API: DELETE /api/public/traces?userId=<uid>
    # See https://langfuse.com/docs/api for the current shape — the v2 endpoint
    # is `DELETE /api/public/traces`. Adjust if running a different version.
    url = f"{settings.langfuse_host.rstrip('/')}/api/public/traces"
    auth = (settings.langfuse_public_key, settings.langfuse_secret_key)
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.delete(url, params={"userId": str(user_id)}, auth=auth)
        if r.status_code >= 300:
            log.warning(
                "langfuse.delete.failed status=%s body=%s", r.status_code, r.text[:200]
            )
            return False
    except Exception:  # noqa: BLE001 — never block the GDPR flow on this
        log.exception("langfuse.delete.error user_id=%s", user_id)
        return False
    log.info("langfuse.delete.ok user_id=%s", user_id)
    return True
