"""Settings via pydantic-settings."""

from __future__ import annotations

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_ASYNC_DRIVERS = ("postgresql+asyncpg://", "sqlite+aiosqlite://")


class Settings(BaseSettings):
    """Runtime config. Surface area mirrored in .env.example."""

    # Database — must use an async driver.
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/postgres"

    # Supabase
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    # Supabase JWT verification
    supabase_jwt_iss: str = ""
    supabase_jwks_url: str = ""
    supabase_jwt_aud: str = "authenticated"
    supabase_jwt_algorithms: str = "ES256"

    # Reports + moderation (ADR 0006)
    report_retention_days: int = 180
    report_context_before: int = 2
    report_context_after: int = 2
    report_rate_limit_count: int = 5
    report_rate_limit_window_minutes: int = 10
    report_internal_action_key: str = ""
    report_action_base_url: str = ""
    report_notification_email: str = ""
    report_notification_email_from: str = ""
    report_notification_hmac_secret: str = ""

    # SMTP
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_use_tls: bool = True

    # Token budget (ADR 0008)
    daily_llm_token_budget: int = 100_000

    # AI service
    ai_service_url: str = "http://localhost:8080"
    ai_request_timeout: float = 30.0

    # Langfuse (ADR 0007 — used by GDPR purge path)
    langfuse_host: str = ""
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""

    # Runtime
    environment: str = "development"
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @field_validator("database_url")
    @classmethod
    def _must_be_async_driver(cls, v: str) -> str:
        if not v.startswith(_ASYNC_DRIVERS):
            raise ValueError(
                f"DATABASE_URL must use an async driver (one of {_ASYNC_DRIVERS}), got: {v[:40]}…"
            )
        return v

    @property
    def jwt_algorithms_list(self) -> list[str]:
        return [a.strip() for a in self.supabase_jwt_algorithms.split(",") if a.strip()]


settings = Settings()
