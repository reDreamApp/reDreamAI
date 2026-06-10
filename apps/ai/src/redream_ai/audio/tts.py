"""Voxtral TTS — generate rehearsal audio, upload to Supabase Storage.

Contract (matches what the backend's `ai_client.generate_rehearsal` calls):
    POST /rehearsal/generate
    -> {audio_url, script, duration_estimate, voice_id, cache_hit}

The AI service uploads the generated MP3 directly to Supabase Storage with a
service-role key and returns a signed URL — the backend persists the URL but
does not see the audio bytes.

TODO(voice): the voice source for Voxtral is an open product decision —
commission a voice, license a CC voice, or record one yourself with consent.
Until the voice IDs in env are populated, this function raises.
"""

from __future__ import annotations

from ..models import RehearsalRequest, RehearsalResponse


async def generate_rehearsal(req: RehearsalRequest) -> RehearsalResponse:
    """Render `req.rewritten_dream` to MP3 via Voxtral, upload, return URL.

    Not yet implemented. Pending:
    - Voice source decision (saved `voice_id` per language).
    - Supabase Storage client setup with service-role key.
    - Audio cache key (sha256 of rewritten_dream + language + voice_id).
    """
    raise NotImplementedError(
        "TTS pending voice source decision (Voxtral ref_audio / saved voice_id)."
    )
