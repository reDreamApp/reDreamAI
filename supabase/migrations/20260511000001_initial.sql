-- Initial schema for reDreamAI (2026-05-11).
--
-- Single source of truth for app-side tables (ADR 0001: one Postgres,
-- shared with self-hosted Supabase's auth + storage). UUID FKs match the
-- pattern used by Supabase's auth.users.
--
-- New tables vs. the legacy schema.sql:
--   - safety_events       (ADR 0005 — crisis-detection audit trail)
--   - user_daily_usage    (ADR 0008 — 100k LLM tokens/user/day budget)
--
-- Dropped from legacy:
--   - Idempotent CREATE / ALTER noise (migrations are forward-only here).
--   - 'telegram' actor_type on report_actions (replaced by 'email' — ADR 0006).
--
-- New columns vs. legacy:
--   - chat_messages.safety_flagged   (ADR 0005)
--   - chat_messages.prompt_version   (audit — which prompt revision authored this)

-- =========================================================================
-- users  (extension of auth.users)
-- =========================================================================
CREATE TABLE public.users (
    id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email               TEXT UNIQUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    gender              TEXT,
    age_range           TEXT,
    nightmare_frequency TEXT
);

CREATE INDEX idx_users_email ON public.users (email);

COMMENT ON TABLE public.users IS
    'App-side extension of auth.users. Profile fields (gender, age_range, nightmare_frequency) only — credentials live in auth.users.';

-- =========================================================================
-- dreams
-- =========================================================================
CREATE TABLE public.dreams (
    id                     BIGSERIAL PRIMARY KEY,
    user_id                UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title                  TEXT NOT NULL,
    original_dream         TEXT NOT NULL,
    rewritten_dream        TEXT,
    intensity              INTEGER CHECK (intensity IS NULL OR (intensity BETWEEN 0 AND 10)),
    is_nightmare           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_edited            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    practice_timestamps    JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_current_dream       BOOLEAN NOT NULL DEFAULT FALSE,
    image_url              TEXT,
    session_id             TEXT,
    source                 TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'chatbot')),
    rehearsal_audio_url    TEXT,
    rehearsal_script       TEXT,
    rehearsal_duration     TEXT,
    rehearsal_language     TEXT CHECK (rehearsal_language IS NULL OR rehearsal_language IN ('en', 'de')),
    rehearsal_generated_at TIMESTAMPTZ
);

CREATE INDEX idx_dreams_user_id     ON public.dreams (user_id);
CREATE INDEX idx_dreams_created_at  ON public.dreams (created_at);
CREATE INDEX idx_dreams_session_id  ON public.dreams (session_id);
CREATE INDEX idx_dreams_source      ON public.dreams (source);

-- =========================================================================
-- chats + chat_messages
-- =========================================================================
CREATE TABLE public.chats (
    id            BIGSERIAL PRIMARY KEY,
    user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    language      TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'de')),
    current_stage TEXT NOT NULL DEFAULT 'recording'
                  CHECK (current_stage IN ('recording', 'intensity', 'rewriting', 'summary', 'final')),
    is_done       BOOLEAN NOT NULL DEFAULT FALSE,
    is_nightmare  BOOLEAN,
    title         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chats_user_id    ON public.chats (user_id);
CREATE INDEX idx_chats_created_at ON public.chats (created_at);

CREATE TABLE public.chat_messages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id             BIGINT NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    role                TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content             TEXT NOT NULL,
    stage               TEXT CHECK (
        stage IS NULL
        OR stage IN ('recording', 'intensity', 'rewriting', 'summary', 'final')
    ),
    visibility_status   TEXT NOT NULL DEFAULT 'visible' CHECK (visibility_status IN ('visible', 'hidden')),
    hidden_at           TIMESTAMPTZ,
    hidden_reason       TEXT,
    hidden_by_report_id UUID,  -- intentional no-FK (cyclic with content_reports; purge job cleans up)
    safety_flagged      BOOLEAN NOT NULL DEFAULT FALSE,
    prompt_version      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_chat_id    ON public.chat_messages (chat_id);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages (created_at);
CREATE INDEX idx_chat_messages_visibility ON public.chat_messages (visibility_status);

COMMENT ON COLUMN public.chat_messages.safety_flagged IS
    'True when the crisis classifier (ADR 0005) returned risk=high for this user message. The IRT machine did not advance on this turn.';
COMMENT ON COLUMN public.chat_messages.prompt_version IS
    'Audit pointer — which redream_ai.prompts.* version generated this assistant message.';

-- =========================================================================
-- daily_moods
-- =========================================================================
CREATE TABLE public.daily_moods (
    id           BIGSERIAL PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mood_date    DATE NOT NULL,
    emotion      TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, mood_date)
);

CREATE INDEX idx_daily_moods_user_id   ON public.daily_moods (user_id);
CREATE INDEX idx_daily_moods_mood_date ON public.daily_moods (mood_date);

-- =========================================================================
-- content_reports + report_actions
-- =========================================================================
CREATE TABLE public.content_reports (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chat_id          BIGINT NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    message_id       UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    target_role      TEXT NOT NULL CHECK (target_role IN ('assistant', 'user')),
    reason           TEXT NOT NULL CHECK (
        reason IN ('child_safety', 'self_harm', 'sexual', 'hate', 'violence', 'harassment', 'deceptive', 'other')
    ),
    details          TEXT,
    status           TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'triaged', 'resolved', 'rejected')),
    severity         TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    content_snapshot TEXT NOT NULL,
    context_snapshot JSONB,
    model            TEXT,
    stage            TEXT,
    language         TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_reports_status_created ON public.content_reports (status, created_at);
CREATE INDEX idx_content_reports_chat_message   ON public.content_reports (chat_id, message_id);
CREATE INDEX idx_content_reports_user_id        ON public.content_reports (user_id);

CREATE TABLE public.report_actions (
    id               BIGSERIAL PRIMARY KEY,
    report_id        UUID NOT NULL REFERENCES public.content_reports(id) ON DELETE CASCADE,
    action           TEXT NOT NULL,
    actor_type       TEXT NOT NULL DEFAULT 'internal' CHECK (actor_type IN ('internal', 'email')),
    actor_id         TEXT,
    note             TEXT,
    actor_ip         TEXT,
    actor_user_agent TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_report_actions_report_created ON public.report_actions (report_id, created_at);

COMMENT ON COLUMN public.report_actions.actor_type IS
    'Source of the moderation action. ''internal'' = admin-view HTTP call; ''email'' = HMAC-signed link click (ADR 0006). Telegram is intentionally absent.';

-- =========================================================================
-- help_center_concerns
-- =========================================================================
CREATE TABLE public.help_center_concerns (
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    email      TEXT,
    message    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_help_center_concerns_user_id ON public.help_center_concerns (user_id);

-- =========================================================================
-- safety_events   (ADR 0005)
-- =========================================================================
CREATE TABLE public.safety_events (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chat_id        BIGINT REFERENCES public.chats(id) ON DELETE SET NULL,
    message_id     UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
    risk           TEXT NOT NULL CHECK (risk IN ('none', 'low', 'high')),
    categories     TEXT[] NOT NULL DEFAULT '{}',
    confidence     DOUBLE PRECISION NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
    action_taken   TEXT NOT NULL DEFAULT 'helpline_shown',
    prompt_version TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_safety_events_user_id    ON public.safety_events (user_id);
CREATE INDEX idx_safety_events_created_at ON public.safety_events (created_at);
CREATE INDEX idx_safety_events_risk       ON public.safety_events (risk);

COMMENT ON TABLE public.safety_events IS
    'Crisis-detection audit trail. Inserted by the backend whenever the AI service''s /safety/classify returns risk=high (ADR 0005). Retention: 180 days, same as content_reports.';

-- =========================================================================
-- user_daily_usage  (ADR 0008)
-- =========================================================================
CREATE TABLE public.user_daily_usage (
    user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    llm_tokens INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date)
);

CREATE INDEX idx_user_daily_usage_date ON public.user_daily_usage (usage_date);

COMMENT ON TABLE public.user_daily_usage IS
    'Per-user per-day LLM token counter for the 100k/day budget (ADR 0008). UTC-day rollover. Incremented by the backend after every AI response (chat + transcription).';

-- =========================================================================
-- Notes on Row Level Security
-- =========================================================================
-- RLS is intentionally NOT enabled on these tables. The backend (apps/api)
-- connects via service-role and bypasses RLS. If any of these tables are
-- ever exposed via PostgREST or the Supabase JS client, add explicit RLS
-- policies first — defense in depth.
