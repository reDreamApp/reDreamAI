"""Per-user daily LLM token budget (ADR 0008).

`DAILY_LLM_TOKEN_BUDGET` tokens per user per day, reset at UTC midnight.
Audio transcription tokens count towards it too.
"""

from __future__ import annotations

from datetime import UTC, datetime, time, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from ..core.clock import utcnow
from ..core.config import settings
from ..db.repositories.usage_repo import UsageRepo


def seconds_until_utc_midnight() -> int:
    now = utcnow()
    midnight = datetime.combine((now + timedelta(days=1)).date(), time.min, tzinfo=UTC)
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
    total = max(0, int(input_tokens) + int(output_tokens))
    if total:
        await UsageRepo(db).increment_today(user_id, tokens=total)
