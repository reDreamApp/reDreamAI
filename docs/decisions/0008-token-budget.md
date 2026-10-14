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

Before inference, ensure daily counter rows with `ON CONFLICT DO NOTHING`,
then conditionally increment the shared and per-user counters in one
transaction only if both have room. All counter updates use SQL arithmetic.
Chat reserves 8192 tokens plus four times the UTF-8 bytes of message/history;
transcription reserves at least 8192, scaled by upload size. Responses settle
to reported usage against the original UTC date. A request that fails in the
AI service gets its reservation back, so a provider outage does not use up the
day. A request the client cancels, and one whose usage is not reported, retain
their reservation: cancelling must not be a way around the limits. A message
stopped by the safety check reserves nothing. A request without room
for its reservation receives HTTP 429 with `Retry-After` until UTC midnight.

New rehearsal audio shares these counters. TTS input is billed per character,
so each stripped Unicode character counts as **8 budget tokens** by default
(`TTS_BUDGET_TOKENS_PER_CHARACTER`). This maps Voxtral's
[$16 per million characters](https://docs.mistral.ai/inference/pricing) to a
rough $2 per million chat-token reference. The reference is an approximation
for mixed chat input/output, not a fixed price for every model or provider.
Adjust the multiplier when pricing changes.

Before asking the AI service for TTS, reserve twice the weighted character
count, with the existing 8192-token reservation minimum. The request explicitly
limits synthesis to two provider attempts. The AI response reports how many
attempts ran; the backend refunds unused capacity, including the whole reserve
for an explicit storage cache hit with zero attempts. Cached audio already on
the dream is refreshed without a reservation and remains available at the cap.
A failed synthesis gives the reserve back; absent or invalid usage retains it.

These are conservative admission estimates. Actual provider usage may exceed
an estimate; auxiliary classifier/routing/critic calls are not fully reflected
by response usage, and TTS price weighting is approximate. These counters are
not an exact ceiling on the provider's invoice.

Audio transcription tokens count against the same budget.

Frontend renders a friendly "you've reached today's limit, comes back tomorrow at 00:00 UTC" card on 429.

## Consequences

### Positive
- Admission limits per user per day; provider billing is not an exact hard ceiling.
- Uses the same daily counters for admission and usage accounting.
- Visible to support: query `user_daily_usage` to diagnose user-reported "AI not responding".

### Negative
- UTC reset is jarring for users in non-UTC zones (resets mid-evening for some). Mitigation: surface "resets at 00:00 UTC" in the limit message; user-tz reset adds complexity not worth it for v1.
- Reservations may reject a request before the counter reaches the configured limit; failed calls keep their reservation until the UTC reset.

## Amendment 2026-10-06 — a limit for all users together

The per-user cap bounds one account, not the service: sign-up is open, so the
bill can still grow with the number of accounts. A second limit covers all
users together: **500k tokens per UTC day** (`DAILY_LLM_TOKEN_BUDGET_TOTAL`).
Chat, transcription and new TTS synthesis answer 429 when there is insufficient
room for a reservation, until midnight UTC, with the same `Retry-After` as the
per-user cap.

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

Not fully counted by either limit: auxiliary safety, routing and critic calls.

## Alternatives considered
- **Per-message rate limit (e.g. 10 req/min)**: doesn't bound cost. Rejected.
- **User-tz reset window**: complexity not justified.
- **Exact cost-based budget**: requires complete usage and pricing for every provider and model. Keep token counters with approximate TTS price weighting for now.
