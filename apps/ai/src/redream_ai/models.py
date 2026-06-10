"""Public wire types for the AI service.

Field names are part of the AI <-> backend JSON contract. Changes here ripple
to `docs/contracts.md` and the backend's `ai_client` module — keep them
deliberate.
"""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class Stage(StrEnum):
    """IRT therapy stages, in canonical forward order (see redream_ai.irt)."""

    RECORDING = "recording"
    INTENSITY = "intensity"
    REWRITING = "rewriting"
    SUMMARY = "summary"
    FINAL = "final"


class Language(StrEnum):
    EN = "en"
    DE = "de"


class Role(StrEnum):
    USER = "user"
    ASSISTANT = "assistant"


class Message(BaseModel):
    """A single conversation turn.

    `stage` is the IRT stage the message belongs to. Persisted by the backend;
    the AI service receives messages on input and emits one on output, but
    never stores anything between requests (ADR 0002).
    """

    role: Role
    content: str
    stage: Stage | None = None
    language: Language | None = None
    timestamp: datetime | None = None


# ---------------------------------------------------------------------------
# /chat — IRT turn
# ---------------------------------------------------------------------------


class ChatRequest(BaseModel):
    """Full conversation history per request (ADR 0002 — stateless AI)."""

    messages: list[Message]
    language: Language
    session_id: str | None = Field(
        default=None,
        description="Optional opaque ID for Langfuse trace grouping. Not used for state.",
    )


class SummaryStructured(BaseModel):
    """Structured fields emitted when stage == SUMMARY (ADR 0003).

    Backend persists these directly into the `dreams` table; no string-matching.
    """

    title: str
    original_summary: str
    rewritten_summary: str
    dream_summary: str


class UsageStats(BaseModel):
    input_tokens: int
    output_tokens: int


class ChatResponse(BaseModel):
    """Non-streaming chat response.

    For streaming (ADR 0009), the SSE event stream emits text chunks followed by
    a final `done` event carrying `{stage, structured, usage, prompt_version}`.
    """

    stage: Stage
    response: str
    structured: SummaryStructured | None = None
    usage: UsageStats
    prompt_version: str

    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------------------
# /safety/classify — crisis pre-classifier (ADR 0005)
# ---------------------------------------------------------------------------


class SafetyRisk(StrEnum):
    NONE = "none"
    LOW = "low"
    HIGH = "high"


class SafetyCategory(StrEnum):
    SUICIDAL_IDEATION = "suicidal_ideation"
    SELF_HARM = "self_harm"
    ABUSE_DISCLOSURE = "abuse_disclosure"
    CHILD_SAFETY = "child_safety"
    IMMINENT_DANGER = "imminent_danger"
    VIOLENCE_TO_OTHERS = "violence_to_others"


class SafetyRequest(BaseModel):
    text: str
    language: Language


class SafetyResponse(BaseModel):
    risk: SafetyRisk
    categories: list[SafetyCategory] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    prompt_version: str


# ---------------------------------------------------------------------------
# /audio/transcribe — Voxtral STT (ADR 0010)
# ---------------------------------------------------------------------------


class TranscribeResponse(BaseModel):
    text: str
    language_detected: Language | None = None
    input_tokens: int = 0
    output_tokens: int = 0


# ---------------------------------------------------------------------------
# /rehearsal/generate — Voxtral TTS + Supabase Storage upload
# ---------------------------------------------------------------------------


class RehearsalRequest(BaseModel):
    dream_id: str
    rewritten_dream: str
    language: Language


class RehearsalResponse(BaseModel):
    audio_url: str = Field(description="Signed Supabase Storage URL for the generated MP3.")
    script: str = Field(description="Text used as TTS input (may be post-processed).")
    duration_estimate: str = Field(description="mm:ss estimate of playback duration.")
    voice_id: str
    cache_hit: bool = False
