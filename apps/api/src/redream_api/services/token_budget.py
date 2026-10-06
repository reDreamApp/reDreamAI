"""Daily LLM token budgets (ADR 0008).

100k tokens / user / day, and 500k / day for all users together. UTC reset.
Audio transcription tokens count too.
"""

from __future__ import annotations

import logging
from datetime import datetime, time, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.repositories.usage_repo import UsageRepo

log = logging.getLogger(__name__)


def seconds_until_utc_midnight() -> int:
    now = datetime.now(timezone.utc)
    tomorrow = (now + timedelta(days=1)).date()
    midnight = datetime.combine(tomorrow, time.min, tzinfo=timezone.utc)
    return int((midnight - now).total_seconds())


async def check_budget(db: AsyncSession, *, user_id: UUID) -> tuple[bool, int]:
    """Return (is_over_budget, retry_after_seconds).

    Call before forwarding any chat or transcription to the AI service. Over
    budget means the user's own limit or the limit of all users together.
    """
    repo = UsageRepo(db)
    if await repo.get_today_tokens(user_id) >= settings.daily_llm_token_budget:
        return True, seconds_until_utc_midnight()
    total = await repo.get_today_total()
    if total >= settings.daily_llm_token_budget_total:
        log.warning(
            "budget.total_exhausted used=%d limit=%d",
            total,
            settings.daily_llm_token_budget_total,
        )
        return True, seconds_until_utc_midnight()
    return False, 0


async def record_usage(
    db: AsyncSession, *, user_id: UUID, input_tokens: int, output_tokens: int
) -> None:
    """Increment today's token counters: the user's and the service-wide one."""
    total = max(0, int(input_tokens) + int(output_tokens))
    if total == 0:
        return
    await UsageRepo(db).increment_today(user_id, tokens=total)
