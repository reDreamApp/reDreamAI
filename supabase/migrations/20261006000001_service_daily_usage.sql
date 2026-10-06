-- Service-wide daily LLM token counter (ADR 0008, amended 2026-10-06).
--
-- One row per UTC day with the tokens of all accounts together. The backend
-- refuses chat and transcription for everyone once the day's row reaches
-- DAILY_LLM_TOKEN_BUDGET_TOTAL.
--
-- It is its own counter and not a sum over user_daily_usage: those rows go
-- away with the account (ON DELETE CASCADE), so a sum would forget what
-- deleted accounts used and the limit could be reset by signing up and
-- deleting again. The table holds no user data.

CREATE TABLE public.service_daily_usage (
    usage_date DATE PRIMARY KEY,
    llm_tokens BIGINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE public.service_daily_usage IS
    'LLM tokens of all users per UTC day, for the service-wide daily budget (ADR 0008). Incremented by the backend together with user_daily_usage.';

-- Start from what is already recorded per user.
INSERT INTO public.service_daily_usage (usage_date, llm_tokens)
SELECT usage_date, SUM(llm_tokens)
FROM public.user_daily_usage
GROUP BY usage_date;

-- Same rule as every app table: RLS on, no policies (see 20261003000001).
ALTER TABLE public.service_daily_usage ENABLE ROW LEVEL SECURITY;
