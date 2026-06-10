"""Supabase Storage helpers — used by the GDPR purge path.

Currently scoped to listing + deleting all objects under `users/{user_id}/`
within the rehearsal-audio bucket.

TODO(impl): wire up the Supabase Python client. Until env is populated this
function logs and returns 0. The GDPR purge route still completes — Postgres
deletion is the load-bearing part; Storage cleanup is best-effort and logged.
"""

from __future__ import annotations

import logging
from uuid import UUID

from ..core.config import settings

log = logging.getLogger(__name__)


async def delete_rehearsal_audio_for_user(user_id: UUID) -> int:
    """Delete every rehearsal audio object owned by `user_id`. Returns count.

    Stub: logs the intent and returns 0 if Supabase config is incomplete.
    """
    if not settings.supabase_url or not settings.supabase_service_role_key:
        log.warning(
            "storage.delete.skipped reason=supabase_not_configured user_id=%s", user_id
        )
        return 0

    # TODO: use supabase.storage.from_(bucket).list(prefix=...) + .remove([paths]).
    log.info(
        "storage.delete.todo user_id=%s bucket=%s prefix=users/%s/",
        user_id,
        settings.supabase_storage_bucket,
        user_id,
    )
    return 0
