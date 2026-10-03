"""Supabase Storage helpers for the GDPR purge path.

Rehearsal audio lives in the AI service's bucket under `dreams/{dream_id}/`
(see `apps/ai/src/redream_ai/audio/tts.py`). The purge lists and removes those
objects over the Storage REST API with the service-role key.
"""

from __future__ import annotations

import logging
from collections.abc import Sequence

import httpx

from ..core.config import settings

log = logging.getLogger(__name__)


async def delete_rehearsal_audio(dream_ids: Sequence[int]) -> int:
    """Delete every rehearsal audio object of the given dreams. Returns the count."""
    if not settings.supabase_url or not settings.supabase_service_role_key:
        log.warning(
            "storage.delete.skipped reason=supabase_not_configured dreams=%d", len(dream_ids)
        )
        return 0
    if not dream_ids:
        return 0

    base = f"{settings.supabase_url.rstrip('/')}/storage/v1/object"
    bucket = settings.supabase_storage_bucket
    headers = {
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "apikey": settings.supabase_service_role_key,
    }
    deleted = 0
    try:
        async with httpx.AsyncClient(headers=headers, timeout=20.0) as client:
            for dream_id in dream_ids:
                prefix = f"dreams/{dream_id}"
                listing = await client.post(
                    f"{base}/list/{bucket}", json={"prefix": prefix, "limit": 1000}
                )
                listing.raise_for_status()
                names = [f"{prefix}/{item['name']}" for item in listing.json() if item.get("name")]
                if not names:
                    continue
                removal = await client.request(
                    "DELETE", f"{base}/{bucket}", json={"prefixes": names}
                )
                removal.raise_for_status()
                deleted += len(names)
    except httpx.HTTPError as exc:
        log.error("storage.delete.failed error=%s deleted_so_far=%d", exc, deleted)
        return deleted

    log.info("storage.delete.done objects=%d dreams=%d", deleted, len(dream_ids))
    return deleted
