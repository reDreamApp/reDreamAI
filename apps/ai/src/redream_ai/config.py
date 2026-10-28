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
    # Needed when the key is restricted to a project other than the
    # organization's default one; empty = default project.
    scaleway_project_id: str = ""

    # Pinned model IDs (ADR 0010 — never floating aliases for prod models).
    # Chat/routing/safety-critic IDs live in core/agent.py::MODELS, not here.
    # Crisis classifier (ADR 0010, 2026-10-21 amendment): Mistral Small on
    # Scaleway primary, Ministral 8B on direct Mistral fallback.
    scaleway_safety_model: str = "mistral-small-3.2-24b-instruct-2506"
    mistral_safety_model: str = "ministral-8b-2512"
    # Speech v3: the German preset needs it; speech v1 (voxtral-mini-tts-2603)
    # rejects it (2026-10-21).
    voxtral_tts_model: str = "voxtral-mini-tts-3-0"
    # STT (ADR 0010, 2026-07-09 amendment): Whisper on Scaleway primary,
    # Voxtral Transcribe V2 on direct Mistral fallback. The Scaleway ID format
    # (org/model:quant) is verbatim from their audio how-to docs.
    whisper_stt_model: str = "openai/whisper-large-v3:fp16"
    voxtral_stt_model: str = "voxtral-mini-2602"

    # TTS needs a voice: a preset slug (GET /v1/audio/voices) or a saved
    # voice id. German: the preset "Heidi" (added 2026-10-19), verified to
    # transcribe back word for word (2026-10-21).
    voxtral_voice_id_en: str = "gb_jane_neutral"
    voxtral_voice_id_de: str = "voice_481"

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_storage_bucket: str = "rehearsal-audio"
    # Host the app can reach, when SUPABASE_URL is an internal compose address.
    supabase_public_url: str = ""
    # Lifetime of the signed rehearsal-audio URL stored on the dream.
    rehearsal_url_ttl_seconds: int = Field(default=300, ge=60, le=3600)

    langfuse_host: str = ""
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""
    # Explicit off-switch (LANGFUSE_ENABLED=false) for all tracing — helpers and
    # @observe decorators alike. Tracing is also off whenever host/keys are unset.
    langfuse_enabled: bool = True

    environment: str = "development"
    log_level: str = "INFO"

    # SAFETY_DEBUG=true: every text model call (guide, routing, crisis
    # classifier, rewrite critic, summaries) goes to Mistral Small 3.2 on
    # Scaleway with no fallback, so a safety-layer debugging run is cheap and
    # every answer comes from one model. Ignored when ENVIRONMENT=production.
    safety_debug: bool = False

    @property
    def small_model_only(self) -> bool:
        return self.safety_debug and self.environment != "production"

    @field_validator("rehearsal_url_ttl_seconds", mode="before")
    @classmethod
    def _migrate_audio_ttl(cls, value: object) -> object:
        return 300 if isinstance(value, (str, int)) and int(value) > 3600 else value

    @field_validator("langfuse_enabled", mode="before")
    @classmethod
    def _empty_means_default(cls, v: object) -> object:
        # A blank `LANGFUSE_ENABLED=` line (the pattern of every other var in
        # .env.example) must not fail service boot — treat it as unset.
        if isinstance(v, str) and not v.strip():
            return True
        return v

    @field_validator("safety_debug", mode="before")
    @classmethod
    def _empty_means_off(cls, v: object) -> object:
        if isinstance(v, str) and not v.strip():
            return False
        return v

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
