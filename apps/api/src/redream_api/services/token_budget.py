"""LLM token budgets (ADR 0008).

Per user and day, for all users together per day, and for all users together
per calendar month (limits in core/config.py). UTC reset. Audio transcription
tokens and price-weighted TTS characters count too.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.repositories.usage_repo import UsageRepo

log = logging.getLogger(__name__)

# Sent to the AI service as an explicit retry ceiling before reserving usage.
TTS_MAX_SYNTHESIS_ATTEMPTS = 2


def seconds_until_utc_midnight() -> int:
    now = datetime.now(UTC)
    tomorrow = (now + timedelta(days=1)).date()
    midnight = datetime.combine(tomorrow, time.min, tzinfo=UTC)
    return int((midnight - now).total_seconds())


def seconds_until_next_month() -> int:
    now = datetime.now(UTC)
    first = (now.replace(day=28) + timedelta(days=4)).replace(day=1)
    start = datetime.combine(first.date(), time.min, tzinfo=UTC)
    return int((start - now).total_seconds())


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
    month = await repo.get_month_total()
    if month >= settings.monthly_llm_token_budget_total:
        log.warning(
            "budget.month_exhausted used=%d limit=%d",
            month,
            settings.monthly_llm_token_budget_total,
        )
        return True, seconds_until_next_month()
    return False, 0


async def record_usage(
    db: AsyncSession, *, user_id: UUID, input_tokens: int, output_tokens: int
) -> None:
    """Increment today's token counters: the user's and the service-wide one."""
    total = max(0, int(input_tokens) + int(output_tokens))
    if total == 0:
        return
    await UsageRepo(db).increment_today(user_id, tokens=total)


# Reserve before inference. A request the client cancels, or one whose usage
# is not reported, retains its reservation: disconnecting cannot bypass limits.
# A request that fails in the AI service gets it back (`release_usage`), so a
# provider outage does not use up the day for everyone. This is a conservative
# admission budget, not a guarantee of the provider's eventual invoice.


@dataclass(frozen=True)
class TokenReservation:
    user_id: UUID
    day: date
    tokens: int


async def reserve_usage(db: AsyncSession, *, user_id: UUID, tokens: int = 8192) -> TokenReservation:
    tokens = max(8192, tokens)
    repo = UsageRepo(db)
    day = await repo.reserve(
        user_id,
        tokens,
        settings.daily_llm_token_budget,
        settings.daily_llm_token_budget_total,
        settings.monthly_llm_token_budget_total,
    )
    if day is None:
        if await repo.get_month_total() + tokens > settings.monthly_llm_token_budget_total:
            retry, which = seconds_until_next_month(), "monthly"
        else:
            retry, which = seconds_until_utc_midnight(), "daily"
        raise HTTPException(
            429,
            f"{which} token budget has insufficient capacity",
            headers={"Retry-After": str(retry)},
        )
    return TokenReservation(user_id, day, tokens)


async def settle_usage(
    db: AsyncSession, reservation: TokenReservation, *, input_tokens: int, output_tokens: int
) -> None:
    actual = max(0, int(input_tokens)) + max(0, int(output_tokens))
    if actual == 0:
        # Missing usage is not evidence that inference was free.
        return
    await UsageRepo(db).adjust(reservation.user_id, reservation.day, actual - reservation.tokens)


async def release_usage(db: AsyncSession, reservation: TokenReservation) -> None:
    """Give a reservation back: the AI service failed, nothing usable came out.

    Only for failures on our side of the request. A request the client
    abandons keeps its reservation, because the provider may still have been
    billed and cancelling must not be a way around the limits. Never raises:
    it runs on error paths that already have their own outcome.
    """
    try:
        await UsageRepo(db).adjust(reservation.user_id, reservation.day, -reservation.tokens)
    except Exception:
        log.exception("budget.release_failed user_id=%s", reservation.user_id)


def tts_budget_tokens(script: str) -> int:
    """Price-weighted units for one synthesis of the exact stripped input."""
    return len(script.strip()) * settings.tts_budget_tokens_per_character


async def settle_tts_usage(
    db: AsyncSession,
    reservation: TokenReservation,
    *,
    tokens_per_attempt: int,
    synthesis_attempts: object,
    cache_hit: object,
) -> None:
    """Refund unused attempts; unreported or invalid usage retains the reserve.

    Only an explicit cache hit with zero provider attempts is free. Keeping
    the reservation when an older AI service omits usage is safe during rollout.
    """
    if type(synthesis_attempts) is not int:
        return
    if not 0 <= synthesis_attempts <= TTS_MAX_SYNTHESIS_ATTEMPTS:
        return
    if synthesis_attempts == 0 and cache_hit is not True:
        return
    actual = tokens_per_attempt * synthesis_attempts
    await UsageRepo(db).adjust(reservation.user_id, reservation.day, actual - reservation.tokens)
