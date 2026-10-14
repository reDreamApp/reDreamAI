"""One-off clean-up: python -m redream_api.revoke_legacy_audio.

Rehearsal audio stored before 2026-10-07 was reachable through links signed
for a year. This renames those objects, so the old links stop working, and
gives every dream a short-lived link.

The deploy calls it after every start. Once no dream points at an old object
it returns after a single query, so the renaming effectively happens once.
"""

import asyncio

from sqlalchemy import func, select

from .db.models.dream import Dream
from .db.session import async_session_maker
from .services.storage_service import refresh_rehearsal_url, revoke_legacy_audio_objects

# Objects written since the change carry this marker in their name.
_CURRENT = "%/v2-%"


async def main() -> None:
    legacy = Dream.rehearsal_audio_url.is_not(None) & Dream.rehearsal_audio_url.not_like(_CURRENT)
    async with async_session_maker() as db:
        pending = await db.scalar(select(func.count()).select_from(Dream).where(legacy))
        if not pending:
            print("rehearsal audio: no old links left, nothing to do")
            return
        # Every old object, including audio of earlier versions of a dream.
        await revoke_legacy_audio_objects()
        dreams = (await db.scalars(select(Dream).where(legacy))).all()
        for dream in dreams:
            assert dream.rehearsal_audio_url is not None
            dream.rehearsal_audio_url = await refresh_rehearsal_url(
                dream.rehearsal_audio_url, dream.user_id, dream.id
            )
            await db.commit()
        print(f"rehearsal audio: old links of {len(dreams)} dream(s) replaced")


if __name__ == "__main__":
    asyncio.run(main())
