"""Supabase Storage cleanup for rehearsal audio (GDPR purge + dream deletion).

apps/ai writes rehearsal MP3s to ``users/{user_id}/{dream_id}/<file>.mp3`` in
the rehearsal-audio bucket. This module deletes them through the Storage REST
API with the service-role key:

- ``POST   /storage/v1/object/list/{bucket}``  ``{"prefix": ...}`` lists one
  folder level (sub-folders come back with ``id: null``)
- ``DELETE /storage/v1/object/{bucket}``       ``{"prefixes": [paths]}``

Best-effort like the Langfuse purge: failures are logged, never raised, so
the Postgres deletion (the load-bearing part) always completes.
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)

_LIST_LIMIT = 1000
_TIMEOUT = 30.0

# Test seam: tests install an httpx.MockTransport here; None means real HTTP.
_transport: httpx.AsyncBaseTransport | None = None


async def delete_rehearsal_audio_for_user(user_id: UUID) -> int:
    """Delete every rehearsal audio object owned by `user_id`. Returns count."""
    return await _purge(f"users/{user_id}", recursive=True)


async def delete_rehearsal_audio_for_dream(user_id: UUID, dream_id: int) -> int:
    """Delete the rehearsal audio of one dream. Returns count."""
    return await _purge(f"users/{user_id}/{dream_id}", recursive=False)


async def _purge(prefix: str, *, recursive: bool) -> int:
    if not settings.supabase_url or not settings.supabase_service_role_key:
        log.warning("storage.delete.skipped reason=supabase_not_configured prefix=%s", prefix)
        return 0
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT, transport=_transport) as client:
            paths = await _list_files(client, prefix, recursive=recursive)
            if paths:
                r = await client.request(
                    "DELETE",
                    f"{_base()}/object/{settings.supabase_storage_bucket}",
                    headers=_headers(),
                    json={"prefixes": paths},
                )
                r.raise_for_status()
    except httpx.HTTPError as exc:
        log.error("storage.delete.failed prefix=%s error=%s", prefix, exc)
        return 0
    log.info("storage.delete.ok prefix=%s count=%d", prefix, len(paths))
    return len(paths)


async def _list_files(client: httpx.AsyncClient, prefix: str, *, recursive: bool) -> list[str]:
    r = await client.post(
        f"{_base()}/object/list/{settings.supabase_storage_bucket}",
        headers=_headers(),
        json={"prefix": prefix, "limit": _LIST_LIMIT},
    )
    r.raise_for_status()
    files: list[str] = []
    entries: list[dict[str, Any]] = r.json()
    for entry in entries:
        path = f"{prefix}/{entry['name']}"
        if entry.get("id") is not None:
            files.append(path)
        elif recursive:
            files += await _list_files(client, path, recursive=True)
    return files


def _base() -> str:
    return f"{settings.supabase_url.rstrip('/')}/storage/v1"


def _headers() -> dict[str, str]:
    key = settings.supabase_service_role_key
    return {"Authorization": f"Bearer {key}", "apikey": key}
