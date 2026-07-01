"""Service configuration via pydantic-settings."""

from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime config. Values come from environment variables or .env.

    Surface area is mirrored in .env.example.
    """

    mistral_api_key: str = Field(default="", description="Mistral API key (fallback path)")
    scaleway_api_key: str = Field(default="", description="Scaleway API key (primary path)")

    # Pinned model IDs (ADR 0010 — never floating aliases for prod models).
    mistral_response_model: str = "mistral-small-4-0-26-03"
    mistral_routing_model: str = "ministral-8b-2512"
    mistral_safety_model: str = "ministral-8b-2512"
    voxtral_tts_model: str = "voxtral-mini-tts-2603"
    voxtral_stt_model: str = "voxtral-mini-latest"

    voxtral_voice_id_en: str = ""
    voxtral_voice_id_de: str = ""

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_storage_bucket: str = "rehearsal-audio"

    langfuse_host: str = ""
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""

    environment: str = "development"
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
