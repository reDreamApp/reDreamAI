"""Dreams CRUD + favorite + practice + rehearsal."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from ....core.clock import utcnow
from ....core.dependencies import CurrentUser, Db
from ....db.models.dream import Dream
from ....db.repositories.dream_repo import DreamRepo
from ....services.ai_client import Ai, AIServiceError
from .schemas import DreamCreate, DreamOut, DreamUpdate, RehearsalGenerateRequest

router = APIRouter(prefix="/dreams", tags=["dreams"])


def _to_out(dream: Dream) -> DreamOut:
    return DreamOut(
        id=dream.id,
        title=dream.title,
        original_dream=dream.original_dream,
        rewritten_dream=dream.rewritten_dream,
        intensity=dream.intensity,
        is_nightmare=dream.is_nightmare,
        created_at=dream.created_at,
        last_edited=dream.last_edited,
        practice_timestamps=list(dream.practice_timestamps or []),
        is_current_dream=dream.is_current_dream,
        image_url=dream.image_url,
        session_id=dream.session_id,
        source=dream.source,
        rehearsal_audio_url=dream.rehearsal_audio_url,
        rehearsal_script=dream.rehearsal_script,
        rehearsal_duration=dream.rehearsal_duration,
        rehearsal_language=dream.rehearsal_language,
        rehearsal_generated_at=dream.rehearsal_generated_at,
    )


async def get_owned_dream(dream_id: int, user: CurrentUser, db: Db) -> Dream:
    """Path dependency: the caller's dream, or 404."""
    dream = await DreamRepo(db).get_for_user(user.id, dream_id)
    if dream is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "dream not found")
    return dream


OwnedDream = Annotated[Dream, Depends(get_owned_dream)]


@router.get("", response_model=list[DreamOut])
async def list_dreams(user: CurrentUser, db: Db) -> list[DreamOut]:
    return [_to_out(d) for d in await DreamRepo(db).list_for_user(user.id)]


@router.get("/{dream_id}", response_model=DreamOut)
async def get_dream(dream: OwnedDream) -> DreamOut:
    return _to_out(dream)


@router.post("", response_model=DreamOut, status_code=status.HTTP_201_CREATED)
async def create_dream(body: DreamCreate, user: CurrentUser, db: Db) -> DreamOut:
    dream = await DreamRepo(db).create(Dream(user_id=user.id, **body.model_dump()))
    return _to_out(dream)


@router.put("/{dream_id}", response_model=DreamOut)
async def update_dream(body: DreamUpdate, dream: OwnedDream, db: Db) -> DreamOut:
    rewritten_changed = (
        body.rewritten_dream is not None and body.rewritten_dream != dream.rewritten_dream
    )
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(dream, field, value)
    dream.last_edited = utcnow()
    if rewritten_changed:
        dream.clear_rehearsal()
    return _to_out(await DreamRepo(db).save(dream))


@router.delete("/{dream_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_dream(dream: OwnedDream, db: Db) -> None:
    await DreamRepo(db).delete(dream)


@router.patch("/{dream_id}/favorite", response_model=DreamOut)
async def set_current_dream(dream: OwnedDream, user: CurrentUser, db: Db) -> DreamOut:
    repo = DreamRepo(db)
    await repo.clear_current_for_user(user.id)
    dream.is_current_dream = True
    return _to_out(await repo.save(dream))


@router.post("/{dream_id}/practice", response_model=DreamOut)
async def record_practice(dream: OwnedDream, db: Db) -> DreamOut:
    dream.practice_timestamps = [
        *(dream.practice_timestamps or []),
        utcnow().isoformat(),
    ]
    return _to_out(await DreamRepo(db).save(dream))


@router.post("/{dream_id}/rehearsal", response_model=DreamOut)
async def generate_rehearsal(
    body: RehearsalGenerateRequest,
    dream: OwnedDream,
    db: Db,
    ai: Ai,
) -> DreamOut:
    if not dream.rewritten_dream:
        raise HTTPException(status.HTTP_409_CONFLICT, "rewritten_dream is required for rehearsal")

    cached = (
        dream.rehearsal_audio_url
        and dream.rehearsal_language == body.language
        and dream.rehearsal_generated_at is not None
    )
    if cached:
        return _to_out(dream)

    try:
        result = await ai.rehearsal_generate(
            {
                "dream_id": str(dream.id),
                "rewritten_dream": dream.rewritten_dream,
                "language": body.language,
            }
        )
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(exc)) from exc

    dream.rehearsal_audio_url = result.get("audio_url")
    dream.rehearsal_script = result.get("script")
    dream.rehearsal_duration = result.get("duration_estimate")
    dream.rehearsal_language = body.language
    dream.rehearsal_generated_at = utcnow()
    return _to_out(await DreamRepo(db).save(dream))
