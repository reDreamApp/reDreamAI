"""Langfuse helpers — used by the GDPR purge path (ADR 0007).

Deletes a user's traces straight in Langfuse's own Postgres database.
Self-hosted Langfuse v2 has no trace-delete endpoint: `DELETE
/api/public/traces` answers 405 on v2.95.11 (seen live 2026-10-03), so the
public API cannot do it. v2 is the end of its line, so its schema is stable:
`traces` carries `user_id`; `observations` and `scores` point at a trace by
`trace_id` without a foreign key, so each table is cleared explicitly.

Traces are found by `user_id`, which apps/ai stamps on every trace from the
`user_id` the backend sends on /chat and /safety/classify.

Best-effort, like the Storage purge: a failure is logged, never raised, so
the Postgres deletion the user asked for still happens.
"""

from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from ..core.config import settings

log = logging.getLogger(__name__)

_USER_TRACE_IDS = "SELECT id FROM traces WHERE user_id = :user_id"

# A session is one chat. Its row holds no content, but nothing of a deleted
# user's chats should stay behind.
_USER_SESSION_IDS = text(
    "SELECT DISTINCT session_id FROM traces WHERE user_id = :user_id AND session_id IS NOT NULL"
)
_DELETE_SCORES = text(f"DELETE FROM scores WHERE trace_id IN ({_USER_TRACE_IDS})")
_DELETE_OBSERVATIONS = text(f"DELETE FROM observations WHERE trace_id IN ({_USER_TRACE_IDS})")
_DELETE_TRACES = text("DELETE FROM traces WHERE user_id = :user_id")
_DELETE_EMPTIED_SESSIONS = text(
    "DELETE FROM trace_sessions WHERE id IN :session_ids "
    "AND NOT EXISTS (SELECT 1 FROM traces WHERE traces.session_id = trace_sessions.id)"
).bindparams(bindparam("session_ids", expanding=True))


async def delete_user_traces(user_id: UUID) -> bool:
    """Delete the user's traces from self-hosted Langfuse.

    Returns True when the deletion ran (including the "no traces" case), False
    if Langfuse's database is not configured or the deletion failed.
    """
    if not settings.langfuse_database_url:
        log.warning("langfuse.delete.skipped reason=not_configured user_id=%s", user_id)
        return False

    params = {"user_id": str(user_id)}
    # A purge is rare: one throwaway connection instead of a second pool.
    engine = create_async_engine(settings.langfuse_database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            session_ids = (await conn.execute(_USER_SESSION_IDS, params)).scalars().all()
            await conn.execute(_DELETE_SCORES, params)
            await conn.execute(_DELETE_OBSERVATIONS, params)
            deleted = (await conn.execute(_DELETE_TRACES, params)).rowcount
            if session_ids:
                await conn.execute(_DELETE_EMPTIED_SESSIONS, {"session_ids": list(session_ids)})
    except Exception:  # never block the GDPR flow on this
        log.exception("langfuse.delete.error user_id=%s", user_id)
        return False
    finally:
        await engine.dispose()
    log.info("langfuse.delete.ok user_id=%s traces=%d", user_id, deleted)
    return True
