"""Voxtral TTS — generate rehearsal audio, upload to Supabase Storage.

    POST /rehearsal/generate -> {audio_url, script, duration_estimate, voice_id, cache_hit}

The AI service uploads the MP3 to Supabase Storage with a service-role key and
returns a signed URL; the backend persists the URL but never sees the bytes.
"""

from __future__ import annotations

from ..models import RehearsalRequest, RehearsalResponse


async def generate_rehearsal(req: RehearsalRequest) -> RehearsalResponse:
    """Not yet implemented. Pending:

    - Voice source decision (commissioned / licensed / self-recorded), stored
      as a `voice_id` per language.
    - Supabase Storage client setup with the service-role key.
    - Audio cache key: sha256 of rewritten_dream + language + voice_id.
    """
    raise NotImplementedError(
        "TTS pending voice source decision (Voxtral ref_audio / saved voice_id)."
    )
