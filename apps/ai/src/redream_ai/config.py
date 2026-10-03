"""Service configuration via pydantic-settings."""

from __future__ import annotations

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime config. Values come from environment variables or .env.

    Surface area is mirrored in .env.example.
    """

    mistral_api_key: str = Field(default="", description="Mistral API key (fallback path)")
    scaleway_api_key: str = Field(default="", description="Scaleway API key (primary path)")

    # Pinned model IDs (ADR 0010 — never floating aliases for prod models).
    # Chat/routing/safety-critic IDs live in core/agent.py::MODELS, not here.
    mistral_safety_model: str = "ministral-8b-2512"
    voxtral_tts_model: str = "voxtral-mini-tts-2603"
    # STT (ADR 0010, 2026-07-09 amendment): Whisper on Scaleway primary,
    # Voxtral Transcribe V2 on direct Mistral fallback. The Scaleway ID format
    # (org/model:quant) is verbatim from their audio how-to docs.
    whisper_stt_model: str = "openai/whisper-large-v3:fp16"
    voxtral_stt_model: str = "voxtral-mini-2602"

    # TTS needs a voice: a preset slug (GET /v1/audio/voices) or a saved
    # voice id. There is no German preset; German text through this English
    # one was verified intelligible (2026-10-01).
    voxtral_voice_id_en: str = "gb_jane_neutral"
    voxtral_voice_id_de: str = "gb_jane_neutral"

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_storage_bucket: str = "rehearsal-audio"
    # Host the app can reach, when SUPABASE_URL is an internal compose address.
    supabase_public_url: str = ""
    # Lifetime of the signed rehearsal-audio URL stored on the dream.
    rehearsal_url_ttl_seconds: int = 60 * 60 * 24 * 365

    langfuse_host: str = ""
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""
    # Explicit off-switch (LANGFUSE_ENABLED=false) for all tracing — helpers and
    # @observe decorators alike. Tracing is also off whenever host/keys are unset.
    langfuse_enabled: bool = True

    environment: str = "development"
    log_level: str = "INFO"

    @field_validator("langfuse_enabled", mode="before")
    @classmethod
    def _empty_means_default(cls, v: object) -> object:
        # A blank `LANGFUSE_ENABLED=` line (the pattern of every other var in
        # .env.example) must not fail service boot — treat it as unset.
        if isinstance(v, str) and not v.strip():
            return True
        return v

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
