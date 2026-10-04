# Roadmap — infra & operational gaps

Prioritized 2026-07-02 (after the chatbot-port + streaming work landed). This is
the operational backlog; product features live in the app issues, architecture
decisions in `docs/decisions/`.

## Now — concrete work, no decision needed

1. ~~**CI test pipeline**~~ DONE (`.github/workflows/ci.yml`): tests for all
   three apps + apps/ai lint and Flutter analyzer gates on PR + push to main;
   apps/api lint runs informational (`continue-on-error`) until the
   lint-baseline cleanup below; plus a migrations-from-zero job
   (`supabase db start` + `migration up --local`).
2. ~~**Rebuild the production box**~~ DONE 2026-10-03. The 2026-07 instance was
   gone; the new one comes from `infra/terraform` (ADR 0012 amendment) plus
   `infra/bootstrap.sh`, which installs Supabase with Supabase's own installer
   and brings the stack up (`infra/README.md`, "First deploy"). Verified from
   outside: sign-up, ES256 token, consent gate, a live chat turn, rehearsal
   audio through a signed URL, account deletion. Runs on the sslip.io test
   domain. The `production` branch deploys to it since 2026-10-03.
3. ~~**Backup job + restore rehearsal**~~ DONE 2026-10-03: nightly timer enabled
   by `bootstrap.sh`, first dump uploaded with the restricted runtime key, and
   one restore rehearsed into a scratch database (log in
   `infra/backup/README.md`).
4. **DNS ownership note** (5 min). `infra/README.md` lists the A records but not
   where the domain is registered, under which account, or who renews it. Also
   remove every record that still points at an earlier server before the new
   box goes live.
5. **Old Supabase Cloud project: confirm it is deleted.** Its one-click restore
   window closed around 2026-10-01 (COMPLIANCE.md §4). Nothing in this repo
   uses it any more.

## Next — needs an ADR before the work

6. **Mobile release pipeline.** Decide: distribution channel (TestFlight /
   Play internal track vs. sideload beta), signing-key custody, versioning
   scheme, CI builds (fastlane/Codemagic vs. manual). Write the ADR when the
   first external tester is a few weeks away — not speculatively before.
7. **Infra monitoring/alerting.** Langfuse watches LLM traces; nothing watches
   "is the box up / disk full / DB connections exhausted". Decision: external
   ping service (healthchecks.io / UptimeRobot) vs. self-hosted uptime-kuma
   vs. Scaleway alerts. The box is a single point of failure, so prefer
   something *off* the box. Small ADR + ~an hour of setup; needed before real
   users.

## Launch gates — must be done before real users, no ADR needed

- ~~**RE-ENABLE THE CRISIS CLASSIFIER + fix its false positive.**~~ DONE
  2026-07-20: `safety-v0.3.1` recalibrates — a message with no risk signal is
  "none" regardless of tone (frustration at the assistant, meta-questions
  like the 2026-07-13 "who are you even" incident, off-topic remarks); the
  err-toward-flagging bias now applies only to ambiguous *genuine* signals.
  Live regression eval: `apps/ai/evals/safety_regression.py` (12 cases incl.
  the incident, real Mistral API — rerun on every prompt edit). Re-enabled in
  prod (`SAFETY_CLASSIFIER_ENABLED` removed from the env override; code
  default true). Local apps/api/.env may still carry `false` for dev.
  2026-10-03: `safety-v0.4.0` adds the dream-vs-waking-life rule (dream
  imagery about one's own death or self-harm, or being a child again, is at
  most "low"; a dream counts as real-life risk only when the user says it
  really happens or happened). The eval grew to 34 cases (dream imagery and
  real-life risk ported from the app_mono eval): v0.3.1 31/34, v0.4.0 34/34
  in three runs on ministral-8b-2512.

Tracked here so they don't live only in session memory. Regulatory details and
sources: `docs/COMPLIANCE.md` (researched 2026-07-06).

- **Wording check** — BEFORE store listing, website, or clinic flyers go
  public: check the exact DE+EN copy against the self-help framing (ADR
  0004): no condition names, no effect claims, no therapy wording.
- **DPIA (Art. 35)** — written data-protection impact assessment; health apps
  are on the DSK must-list. Biggest missing compliance artifact.
- **Art. 9 consent flow** — CODE DONE 2026-07-10 (one bundled consent,
  Daniel's decision): `user_consents` proof log (migration
  20260710000001), grant/withdraw endpoints, `require_consent` gate on
  health-data routes, blocking consent screen after sign-in + settings
  withdrawal. Consent version `2026-10-03` names Mistral for AI responses and
  rehearsal audio. STILL OPEN: Verzeichnis von Verarbeitungstätigkeiten,
  documented TOMs.
- **Vendor DPAs**: sign/collect Scaleway + Mistral DPAs (both self-serve);
  request Mistral zero-data-retention, disclose their 30-day abuse-monitoring
  window in the privacy policy until granted.
- ~~**Langfuse erasure path**~~ DONE 2026-10-03 (ADR 0007 amendment). apps/ai
  stamps every trace with the backend-sent `user_id`/`session_id`, and
  `delete_user_traces` deletes them directly in the `langfuse` database
  (`scores`, `observations`, `traces`, emptied sessions). The earlier version
  called `DELETE /api/public/traces`, which the self-hosted v2 server answers
  with `405`; it had only been checked against the OpenAPI spec. Verified on
  the box: two traces and three observations before account deletion, none
  after.
- ~~**Langfuse retention TTL**~~ DONE 2026-10-03: `infra/langfuse/retention.sh`
  runs daily from a systemd timer (enabled by `bootstrap.sh`) and deletes
  traces, observations and scores stored more than 30 days ago, plus emptied
  sessions. Langfuse v2 has no setting for this, so it is SQL in its database.
  The period is `LANGFUSE_RETENTION_DAYS`. Checked on the box with seeded rows
  (29-day-old kept, 31-day-old removed).
- **Mail delivery.** No SMTP on the box and Scaleway blocks ports 25/465/587:
  sign-up auto-confirms addresses, and password-reset and moderation mails
  (ADR 0006) are not delivered. Needs an SMTP relay on another port.
- **Edge rate limiting**: Caddy has no request-flood protection (the ADR 0008
  token budget only caps per-user LLM cost). Needs the non-bundled Caddy
  rate-limit module — a deliberate image build change, ~half a day.
- **Crisis feature UX**: user-visible behavior must be signposting only
  (locale-correct hotline numbers, e.g. Telefonseelsorge 0800 111 0 111) —
  never a risk score or "crisis detected" label (COMPLIANCE.md §1).
- **At launch: DB → Scaleway Managed PostgreSQL** (Art. 32 upgrade; Supabase
  components keep running self-hosted against it). Test pgcrypto/pgjwt/role
  availability on Managed PG first.

## Deferred deliberately

- **TTS voice choice** — TTS is implemented (2026-10-01, ADR 0010 amendment) with the
  Mistral preset `gb_jane_neutral` for both languages. Still open: a proper German voice
  (record Daniel vs. hire a speaker vs. the user's own voice, which adds Art. 9 biometric
  consent and purge scope).
- **Staging environment** — the release topology (RELEASING.md: preview
  branches / local stack for schema, `production` as the only deploy gate)
  covers pre-launch risk. A standing staging box is a solo-dev time sink;
  revisit when a bad deploy would hurt real users.
- **Monetization/billing** — open product question, not engineering. Write the
  ADR when the business model is actually decided; billing code before a
  business model is speculation.
- **Lint-baseline cleanup** — apps/api (ruff B008/UP017 + 14 mypy errors as of
  2026-10-03) is red at baseline with zero new issues from recent work. One
  dedicated cleanup pass whenever convenient; unblocks strict CI gating
  (item 1). apps/app is clean since the 2026-10 frontend port and its analyzer
  is a CI gate.
