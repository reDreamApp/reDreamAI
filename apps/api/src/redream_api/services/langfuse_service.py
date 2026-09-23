"""Langfuse trace deletion for the GDPR purge path (ADR 0007).

Best-effort: the user-facing deletion is Postgres-bound, so an unreachable or
unconfigured Langfuse is logged and reported as False, never raised.
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
        log.warning("langfuse.delete.skipped reason=not_configured user_id=%s", user_id)
        return False

    # Langfuse v2: DELETE /api/public/traces?userId=<uid>
    url = f"{settings.langfuse_host.rstrip('/')}/api/public/traces"
    auth = (settings.langfuse_public_key, settings.langfuse_secret_key)
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.delete(url, params={"userId": str(user_id)}, auth=auth)
    except httpx.HTTPError:
        log.exception("langfuse.delete.error user_id=%s", user_id)
        return False

    if r.status_code >= 300:
        log.warning("langfuse.delete.failed status=%s body=%s", r.status_code, r.text[:200])
        return False

    log.info("langfuse.delete.ok user_id=%s", user_id)
    return True
