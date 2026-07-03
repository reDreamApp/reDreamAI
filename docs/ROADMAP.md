# Roadmap — infra & operational gaps

Prioritized 2026-07-02 (after the chatbot-port + streaming work landed). This is
the operational backlog; product features live in the app issues, architecture
decisions in `docs/decisions/`.

## Now — concrete work, no decision needed

1. **CI test pipeline** (~half a day). `.github/workflows/` has only
   `deploy.yml`; nothing stops a broken PR from merging. Add a workflow running
   on PR + push to main: `pytest` for apps/ai and apps/api, `flutter test` via
   FVM. Gate on **tests + apps/ai lint only** — apps/api ruff/mypy (80/15
   errors) and the Flutter analyzer (366 infos) are red at baseline; pin those
   counts as "no new errors" checks or leave them non-blocking until the
   cleanup pass below, otherwise CI is red on day one and gets ignored.
2. **Backup job + restore rehearsal** (~a day). Bucket + retention exist; still
   missing: the scheduled `pg_dump` upload (cron/systemd timer on the host) and
   a written restore runbook that has been **rehearsed once** against a scratch
   database. A backup nobody has restored from is a hope, not a backup.
3. **DNS ownership note** (5 min). `infra/README.md` says "point three
   A records" but not where the domain is registered, under which account, or
   who renews it. One paragraph; batch into the next infra commit.

## Next — needs an ADR before the work

4. **Mobile release pipeline.** Decide: distribution channel (TestFlight /
   Play internal track vs. sideload beta), signing-key custody, versioning
   scheme, CI builds (fastlane/Codemagic vs. manual). Write the ADR when the
   first external tester is a few weeks away — not speculatively before.
5. **Infra monitoring/alerting.** Langfuse watches LLM traces; nothing watches
   "is the box up / disk full / DB connections exhausted". Decision: external
   ping service (healthchecks.io / UptimeRobot) vs. self-hosted uptime-kuma
   vs. Scaleway alerts. The box is a single point of failure, so prefer
   something *off* the box. Small ADR + ~an hour of setup; needed before real
   users.

## Launch gates — must be done before real users, no ADR needed

Tracked here so they don't live only in session memory:

- **Vendor DPAs**: sign/collect data-processing agreements with Mistral and
  Scaleway (both offer standard/self-serve DPAs). Legal paperwork, not
  architecture.
- **Langfuse erasure path**: `delete_langfuse_user_data()` is still a no-op —
  implement deletion by `session_id` (GDPR purge must reach traces).
- **Langfuse retention TTL** (30–90 d) on traces.
- **DPO/lawyer pass** on the special-category (Art. 9) data handling.
- **Edge rate limiting**: Caddy has no request-flood protection (the ADR 0008
  token budget only caps per-user LLM cost). Needs the non-bundled Caddy
  rate-limit module — a deliberate image build change, ~half a day.

## Deferred deliberately

- **Staging environment** — the release topology (RELEASING.md: preview
  branches / local stack for schema, `production` as the only deploy gate)
  covers pre-launch risk. A standing staging box is a solo-dev time sink;
  revisit when a bad deploy would hurt real users.
- **Monetization/billing** — open product question, not engineering. Write the
  ADR when the business model is actually decided; billing code before a
  business model is speculation.
- **Lint-baseline cleanup** — apps/api (80 ruff / 15 mypy) and apps/app
  (366 analyzer infos) are red at baseline with zero new issues from recent
  work. One dedicated cleanup pass each, whenever convenient; unblocks strict
  CI gating (item 1).
