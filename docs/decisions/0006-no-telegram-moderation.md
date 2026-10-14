# 0006 — Moderation alerts via email + HMAC-signed links (not Telegram)

- Status: accepted
- Date: 2026-05-11
- Deciders: Daniel

## Context
Legacy backend sends content reports to Telegram with the user's actual dream narrative in the message body (`content_snapshot` + `context_snapshot`). Telegram is a third-country processor with no EU adequacy. For a mental-health adjacent app handling sensitive personal narratives, this is hard to justify to a DPO.

## Decision
Replace Telegram with **email + HMAC-signed action links**. Notifications contain only:
- Report ID
- Reason + severity
- Target role (assistant / user)
- A signed link to the admin view

Content stays in Postgres. The admin view (gated by `REPORT_INTERNAL_ACTION_KEY` + IP allowlist) shows the snapshot when the moderator clicks through.

Email links point to `/internal/reports/{id}/resolve|reject` and
`/internal/messages/{id}/hide`. They carry an expiry and random nonce bound to
the HMAC signature. GET displays a confirmation form; POST consumes the nonce,
applies the action and records the audit in one transaction. A backend-only
`moderation_tokens` table prevents reuse across API processes and restarts.
Links default to a 24-hour lifetime. Empty signing secrets fail closed.
URL capabilities and referrers are omitted from proxy access logs; the
production API disables Uvicorn's raw request access logging.

If volume becomes painful, the next step is self-hosted Mattermost in the same compose stack, not back to Telegram.

## Consequences

### Positive
- No PII leaves EU jurisdiction in notifications.
- Less infrastructure than Telegram bot + webhook callbacks (one less inbound `/internal/telegram/webhook`).
- Resolve, reject and hide actions use signed confirmation links without a separate moderator login.

### Negative
- No realtime feel (email vs Telegram push). Acceptable for moderation volume.
- No inline-button UX. Mitigation: action links work in any mail client.

## Alternatives considered
- **Telegram (legacy)**: rejected (data residency).
- **Signal via signal-cli**: one-way only, no inline buttons, operationally fiddly.
- **Self-hosted Mattermost**: realtime + buttons + EU-resident, but adds a service. Defer until email-based volume becomes painful.
- **Self-hosted Matrix / Element (Synapse)**: heavier ops. Defer.
- **In-app moderation panel**: cleanest but more UI to build. Could replace email later.
