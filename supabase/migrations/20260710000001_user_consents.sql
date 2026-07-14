-- Explicit consent for health-data processing (GDPR Art. 9(2)(a)).
--
-- Append-only proof log (Art. 7(1) demonstrability): every grant and every
-- withdrawal is a new row; the user's current status is the LATEST row for
-- the consent key. `version` records which consent-text version the user
-- actually saw (bumped in apps/api settings on material copy changes —
-- a bump forces re-consent). Rows cascade away with the account: erasure
-- trumps demonstrability.
CREATE TABLE public.user_consents (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_key TEXT NOT NULL DEFAULT 'health_data_processing',
    version     TEXT NOT NULL,
    granted     BOOLEAN NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_consents_user_key
    ON public.user_consents (user_id, consent_key, id DESC);

COMMENT ON TABLE public.user_consents IS
    'Explicit-consent proof log (GDPR Art. 9(2)(a) + Art. 7(1)). One bundled consent covers the full named processing chain (Scaleway, Mistral, self-hosted tracing) — decided 2026-07-10.';
