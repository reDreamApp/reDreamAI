"""Per-user daily LLM token budget (ADR 0008).

100k tokens / user / day. UTC reset. Audio transcription tokens count too.
"""

from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.repositories.usage_repo import UsageRepo


def seconds_until_utc_midnight() -> int:
    now = datetime.now(timezone.utc)
    tomorrow = (now + timedelta(days=1)).date()
    midnight = datetime.combine(tomorrow, time.min, tzinfo=timezone.utc)
    return int((midnight - now).total_seconds())


async def check_budget(db: AsyncSession, *, user_id: UUID) -> tuple[bool, int]:
    """Return (is_over_budget, retry_after_seconds).

    Call before forwarding any chat or transcription to the AI service.
    """
    used = await UsageRepo(db).get_today_tokens(user_id)
    if used >= settings.daily_llm_token_budget:
        return True, seconds_until_utc_midnight()
    return False, 0


async def record_usage(
    db: AsyncSession, *, user_id: UUID, input_tokens: int, output_tokens: int
) -> None:
    """Increment the user's token counter for today."""
    total = max(0, int(input_tokens) + int(output_tokens))
    if total == 0:
        return
    await UsageRepo(db).increment_today(user_id, tokens=total)
