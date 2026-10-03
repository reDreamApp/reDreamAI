"""Langfuse helpers — used by the GDPR purge path (ADR 0007).

Replaces the legacy `langfuse_service.delete_langfuse_user_data` no-op stub.
This implementation is best-effort: it deletes the user's traces via the
Langfuse public API and logs the outcome. The GDPR purge does not fail if
Langfuse is unreachable — the user-facing deletion is Postgres-bound (also
best-effort for Storage).

Traces are found by ``userId``, which apps/ai stamps on every trace from the
``user_id`` the backend sends on /chat and /safety/classify. The Langfuse API
has no delete-by-user endpoint — the shape (verified against the Langfuse
OpenAPI spec, fern/apis/server/definition/trace.yml) is:

- ``GET  /api/public/traces?userId=&page=&limit=`` — paginated listing
- ``DELETE /api/public/traces`` with body ``{"traceIds": [...]}`` — bulk delete
  (server-side deletion is queued/async; a re-list right after may still show
  the traces, so we list fully first, then delete)
"""

from __future__ import annotations

import logging
from uuid import UUID

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)

_LIST_PAGE_LIMIT = 100
_DELETE_CHUNK = 100

# Test seam: tests install an httpx.MockTransport here; None means real HTTP.
_transport: httpx.AsyncBaseTransport | None = None


def _traces_url() -> str:
    return f"{settings.langfuse_host.rstrip('/')}/api/public/traces"


async def _list_user_trace_ids(client: httpx.AsyncClient, user_id: UUID) -> list[str]:
    """All trace ids for the user, across pages. Raises on non-2xx."""
    trace_ids: list[str] = []
    page = 1
    while True:
        r = await client.get(
            _traces_url(),
            params={"userId": str(user_id), "page": page, "limit": _LIST_PAGE_LIMIT},
        )
        r.raise_for_status()
        payload = r.json()
        trace_ids.extend(t["id"] for t in payload.get("data", []))
        total_pages = int(payload.get("meta", {}).get("totalPages", 1))
        if page >= total_pages:
            return trace_ids
        page += 1


async def delete_user_traces(user_id: UUID) -> bool:
    """Delete the user's traces from self-hosted Langfuse.

    Returns True when every found trace was accepted for deletion (including
    the "no traces" case), False if Langfuse is not configured, unreachable,
    or any request failed.
    """
    if not settings.langfuse_host or not settings.langfuse_public_key:
        log.warning("langfuse.delete.skipped reason=not_configured user_id=%s", user_id)
        return False

    auth = (settings.langfuse_public_key, settings.langfuse_secret_key)
    try:
        async with httpx.AsyncClient(timeout=30.0, auth=auth, transport=_transport) as client:
            trace_ids = await _list_user_trace_ids(client, user_id)
            for i in range(0, len(trace_ids), _DELETE_CHUNK):
                chunk = trace_ids[i : i + _DELETE_CHUNK]
                # httpx.delete() takes no body — DELETE /api/public/traces
                # requires {"traceIds": [...]} in the body, so use request().
                r = await client.request("DELETE", _traces_url(), json={"traceIds": chunk})
                r.raise_for_status()
    except Exception:  # never block the GDPR flow on this
        log.exception("langfuse.delete.error user_id=%s", user_id)
        return False
    log.info("langfuse.delete.ok user_id=%s traces=%d", user_id, len(trace_ids))
    return True
