"""Supabase Storage helpers for the GDPR purge path.

TODO(impl): wire up the Supabase client — list + remove everything under
`users/{user_id}/` in the rehearsal-audio bucket. Until then this logs and
returns 0; the purge route still completes because Postgres deletion is the
load-bearing part.
"""

from __future__ import annotations

import logging
from uuid import UUID

from ..core.config import settings

log = logging.getLogger(__name__)


async def delete_rehearsal_audio_for_user(user_id: UUID) -> int:
    """Delete every rehearsal audio object owned by `user_id`. Returns the count."""
    if not settings.supabase_url or not settings.supabase_service_role_key:
        log.warning("storage.delete.skipped reason=supabase_not_configured user_id=%s", user_id)
        return 0

    log.info(
        "storage.delete.todo user_id=%s bucket=%s prefix=users/%s/",
        user_id,
        settings.supabase_storage_bucket,
        user_id,
    )
    return 0
