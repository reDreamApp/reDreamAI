"""Voxtral TTS — generate rehearsal audio, upload to Supabase Storage.

    POST /rehearsal/generate -> {audio_url, script, duration_estimate, voice_id, cache_hit}

The MP3 is cached in the bucket under a content hash, so regenerating the same
rewritten dream never re-synthesizes. The backend persists the URL only.
"""

from __future__ import annotations

import hashlib
import math

from ..models import Language, RehearsalRequest, RehearsalResponse
from .base import AudioStorage, Synthesizer

_WORDS_PER_SECOND = 2.4


async def generate_rehearsal(
    req: RehearsalRequest,
    *,
    synthesizer: Synthesizer,
    storage: AudioStorage,
    model: str,
    voice_ids: dict[Language, str],
    url_ttl_seconds: int,
) -> RehearsalResponse:
    script = req.rewritten_dream.strip()
    voice_id = voice_ids.get(req.language) or ""
    path = _object_path(req.dream_id, script, req.language, voice_id)

    cache_hit = await storage.exists(path)
    if not cache_hit:
        audio = await synthesizer.synthesize(text=script, model=model, voice_id=voice_id or None)
        await storage.upload(path, audio, content_type="audio/mpeg")

    return RehearsalResponse(
        audio_url=await storage.signed_url(path, expires_in=url_ttl_seconds),
        script=script,
        duration_estimate=estimate_duration(script),
        voice_id=voice_id or "default",
        cache_hit=cache_hit,
    )


def estimate_duration(script: str) -> str:
    seconds = math.ceil(len(script.split()) / _WORDS_PER_SECOND)
    return f"{seconds // 60:02d}:{seconds % 60:02d}"


def _object_path(dream_id: str, script: str, language: Language, voice_id: str) -> str:
    digest = hashlib.sha256(f"{script}|{language.value}|{voice_id}".encode()).hexdigest()[:24]
    return f"dreams/{dream_id}/{language.value}-{digest}.mp3"
