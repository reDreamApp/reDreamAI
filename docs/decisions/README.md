# Architecture Decision Records

This folder holds the binding architectural decisions for the reDreamAI rebuild. Each ADR uses a lightweight MADR-style format: context, decision, consequences, alternatives.

## Index

- [0001 — Single Postgres (self-hosted Supabase's)](0001-one-postgres.md)
- [0002 — Stateless AI service](0002-stateless-ai-service.md)
- [0003 — Structured outputs for routing and summary](0003-structured-outputs.md)
- [0004 — Position as self-help, not therapy](0004-self-help-framing.md)
- [0005 — Crisis detection before IRT routing](0005-crisis-detection.md)
- [0006 — Moderation alerts via email + HMAC-signed links](0006-no-telegram-moderation.md)
- [0007 — Self-hosted Langfuse v2 (not cloud, not v3)](0007-langfuse-v2-self-hosted.md)
- [0008 — 100k LLM tokens / user / day, 500k for all users](0008-token-budget.md)
- [0009 — Streaming chat via SSE end-to-end](0009-streaming-chat.md)
- [0010 — Pinned Mistral / Voxtral model IDs](0010-mistral-models-pinned.md)
- [0011 — Postgres connection mode: Supavisor pooler everywhere](0011-postgres-connection-mode.md)
- [0012 — Terraform for Scaleway infra provisioning](0012-terraform-scaleway.md)

## Status conventions

- **accepted** — current binding decision
- **superseded by ADR-NNNN** — historical, do not follow
- **proposed** — under discussion, not yet binding

## Workflow

1. New decision: create `NNNN-short-slug.md`, status `proposed`, open a PR.
2. Revising an accepted decision: write a new ADR that supersedes the old one. Edit the old one only to change its status to `superseded by ADR-NNNN`.
3. Never delete an ADR — they're the audit trail of why the architecture is what it is.
