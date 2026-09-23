"""Profile routes — gender / age_range / nightmare_frequency."""

from __future__ import annotations

from fastapi import APIRouter

from ....core.dependencies import CurrentUser, Db
from ....db.models.user import User
from .schemas import NightmareFrequencyUpdate, ProfileOut, ProfileUpdate

router = APIRouter(prefix="/profile", tags=["profile"])


def _to_out(user: User) -> ProfileOut:
    return ProfileOut(
        gender=user.gender,
        age_range=user.age_range,
        nightmare_frequency=user.nightmare_frequency,
    )


@router.get("", response_model=ProfileOut)
async def read_profile(user: CurrentUser) -> ProfileOut:
    return _to_out(user)


@router.post("", response_model=ProfileOut)
async def upsert_profile(body: ProfileUpdate, user: CurrentUser, db: Db) -> ProfileOut:
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return _to_out(user)


@router.patch("/nightmare-frequency", response_model=ProfileOut)
async def patch_nightmare_frequency(
    body: NightmareFrequencyUpdate, user: CurrentUser, db: Db
) -> ProfileOut:
    user.nightmare_frequency = body.nightmare_frequency
    await db.commit()
    await db.refresh(user)
    return _to_out(user)
