"""Progress: rehearsal streak, intensity avg, mood avg, today's mood."""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, datetime, timedelta

from fastapi import APIRouter, status

from ....core.clock import today_utc
from ....core.dependencies import CurrentUser, Db
from ....db.models.dream import Dream
from ....db.repositories.daily_mood_repo import DailyMoodRepo
from ....db.repositories.dream_repo import DreamRepo
from .schemas import DailyMoodUpdate, ProgressStatsOut

router = APIRouter(prefix="/progress", tags=["progress"])

_MOOD_TO_SCORE = {
    "Very Dissatisfied": 1.0,
    "Dissatisfied": 2.0,
    "Neutral": 3.0,
    "Satisfied": 4.0,
    "Very Satisfied": 5.0,
}

_MOOD_WINDOW_DAYS = 30


def _mean(values: Sequence[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _practice_days(dreams: Sequence[Dream]) -> set[date]:
    days: set[date] = set()
    for dream in dreams:
        for ts in dream.practice_timestamps or []:
            try:
                days.add(datetime.fromisoformat(str(ts).replace("Z", "+00:00")).date())
            except ValueError:
                continue
    return days


def _rehearsal_streak(dreams: Sequence[Dream]) -> int:
    """Consecutive days ending today with at least one practice timestamp."""
    days = _practice_days(dreams)
    today = today_utc()
    streak = 0
    while today - timedelta(days=streak) in days:
        streak += 1
    return streak


@router.get("/stats", response_model=ProgressStatsOut)
async def get_stats(user: CurrentUser, db: Db) -> ProgressStatsOut:
    dreams = await DreamRepo(db).list_for_user(user.id, limit=1000)
    nightmares = [d for d in dreams if d.is_nightmare]

    today = today_utc()
    moods = await DailyMoodRepo(db).list_for_user_between(
        user.id, start=today - timedelta(days=_MOOD_WINDOW_DAYS - 1), end=today
    )
    today_mood = next((m.emotion for m in moods if m.mood_date == today), None)

    return ProgressStatsOut(
        rehearsal_streak=_rehearsal_streak(dreams),
        average_intensity=_mean([d.intensity for d in nightmares if d.intensity is not None]),
        average_mood=_mean(
            [s for s in (_MOOD_TO_SCORE.get(m.emotion) for m in moods) if s is not None]
        ),
        today_mood=today_mood,
        dreams_logged=len(dreams),
        nightmares_treated=sum(1 for d in nightmares if d.rewritten_dream),
    )


@router.post("/emotion", status_code=status.HTTP_204_NO_CONTENT)
async def upsert_today_mood(body: DailyMoodUpdate, user: CurrentUser, db: Db) -> None:
    await DailyMoodRepo(db).upsert_for_user_date(
        user_id=user.id, mood_date=today_utc(), emotion=body.emotion
    )
