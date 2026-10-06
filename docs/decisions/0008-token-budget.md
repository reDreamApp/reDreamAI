# 0008 — 100k LLM tokens / user / day

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Mistral API charges per token. Without a per-user cap, a malicious user, runaway client, or buggy retry loop can rack up large bills. Legacy backend rate-limits reports (5 / 10min) but has no token budget on chat.

## Decision
Track LLM usage per user per UTC day in Postgres:

```sql
CREATE TABLE user_daily_usage (
  user_id     uuid NOT NULL,
  usage_date  date NOT NULL,
  llm_tokens  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, usage_date)
);
```

Backend increments `llm_tokens` after every AI response (sum of input + output tokens from the Mistral `usage` block). Before forwarding a chat or transcription request, check:

```sql
SELECT COALESCE(llm_tokens, 0) FROM user_daily_usage
  WHERE user_id = $1 AND usage_date = CURRENT_DATE;
```

If `>= 100000`: return HTTP 429 with `{ retry_after: <seconds_until_utc_midnight> }`.

Audio transcription tokens count against the same budget.

Frontend renders a friendly "you've reached today's limit, comes back tomorrow at 00:00 UTC" card on 429.

## Consequences

### Positive
- Hard cost ceiling per user per day.
- Cheap to implement (one table, two queries).
- Visible to support: query `user_daily_usage` to diagnose user-reported "AI not responding".

### Negative
- UTC reset is jarring for users in non-UTC zones (resets mid-evening for some). Mitigation: surface "resets at 00:00 UTC" in the limit message; user-tz reset adds complexity not worth it for v1.
- Counter is post-hoc (incremented after response), so a single very large turn can push past 100k. Mitigation: also enforce a per-message `max_tokens` ceiling in the Mistral call.

## Amendment 2026-10-06 — a limit for all users together

The per-user cap bounds one account, not the service: sign-up is open, so the
bill can still grow with the number of accounts. A second limit covers all
users together: **500k tokens per UTC day** (`DAILY_LLM_TOKEN_BUDGET_TOTAL`).
Once the day's total reaches it, chat and transcription answer 429 for
everyone until midnight UTC, with the same `Retry-After` as the per-user cap.

The total is its own counter:

```sql
CREATE TABLE service_daily_usage (
  usage_date  date PRIMARY KEY,
  llm_tokens  bigint NOT NULL DEFAULT 0
);
```

It is incremented together with `user_daily_usage`. It is not a sum over that
table, because those rows are deleted with the account (`ON DELETE CASCADE`):
a sum would forget what deleted accounts used, and the limit could be reset by
signing up, using the budget and deleting the account again. The table holds
no user data.

Not counted, by either limit: the safety check before each turn and the
rehearsal audio (TTS is billed per character, not per token).

## Alternatives considered
- **Per-message rate limit (e.g. 10 req/min)**: doesn't bound cost. Rejected.
- **User-tz reset window**: complexity not justified.
- **Cost-based instead of token-based budget**: requires pricing data baked in; cleaner to count tokens.
