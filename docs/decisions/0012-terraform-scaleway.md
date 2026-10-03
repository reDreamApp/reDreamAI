# 0012 — Terraform for Scaleway infra provisioning

- Status: accepted; scope is the whole Scaleway side of the box (narrowed 2026-07-02, widened again 2026-10-03 — see Amendments)
- Date: 2026-07-02
- Deciders: Daniel

## Context

Per `infra/README.md`, the Scaleway side of production is provisioned entirely by hand: create the compute instance via the Scaleway console (GP1-S, Ubuntu 24.04, Paris), configure the firewall to allow 22/80/443, SSH in to install Docker, and separately point DNS A records at the instance's IP. None of this is checked in or versioned — the instance's existence and configuration live only in the Scaleway console and in whoever did the setup.

This is a single-instance, single-operator (solo dev) setup today, so the manual process has been tolerable. But it has no reproducibility or disaster-recovery story: if the instance is lost or needs replacing, someone has to remember and re-execute the console steps from `infra/README.md` exactly, by hand, under pressure. It also means infra changes (resizing the instance, adding a firewall rule, adding the Object Storage bucket for backups mentioned in `infra/README.md` as "recommended not yet automated") happen as untracked console clicks with no diff, review, or history.

App deployment itself is already handled separately and is out of scope here: `.github/workflows/deploy.yml` rsyncs the repo and runs `docker compose up -d --build` on the box, manually triggered (`workflow_dispatch`), no auto-deploy on `main`. That layer is unaffected by this decision.

## Decision

Adopt Terraform (Scaleway provider, `scaleway/scaleway`) to define and provision the Scaleway resource layer as code, under `infra/terraform/`:

- The compute instance (type, image, zone, boot config).
- The firewall / security group (22, 80, 443).
- The Object Storage bucket for Postgres backups (currently listed as a manual TODO in `infra/README.md`).
- DNS records, if managed via Scaleway DNS (otherwise left with the current registrar and just documented).

Terraform state is remote — a Scaleway Object Storage bucket configured as an S3-compatible backend, not local state, so it survives a lost laptop and isn't committed to git.

Terraform owns cloud *resources* only. It does not touch app deployment (`docker compose up`, image builds, env files) — that stays exactly as documented in `infra/README.md` and `.github/workflows/deploy.yml`. `infra/README.md`'s "First-time setup" steps 1–2 (provision instance, install Docker via a small cloud-init/user-data script) are replaced by `terraform apply`; steps 3 onward (Supabase install, env files, DNS, `docker compose up`) are unchanged.

## Consequences

### Positive
- The instance, firewall, and backup bucket become reproducible from a `terraform apply` instead of tribal knowledge in a README.
- Infra changes go through a diff (`terraform plan`) before they happen, and are reviewable in a PR like any other change.
- Disaster recovery becomes "run terraform apply, then follow the unchanged app-deploy steps" instead of manually redoing console clicks from memory.
- Closes the "Object Storage backups not yet automated" gap called out in `infra/README.md`.

### Negative
- New tool to install and maintain solo (Terraform CLI, provider version pinning, remote state backend).
- A remote state bucket becomes a new single point of failure/secret to manage — needs its own access key, and state can contain sensitive values (must confirm nothing secret ends up unencrypted in state, or use `sensitive = true` / keep secrets out of Terraform entirely and injected via the existing `infra/env/*.env` files).
- If anyone (including future-Daniel) SSHes in and changes something by hand, Terraform state drifts silently until the next `plan`/`apply`.
- Upfront cost of writing and testing the initial Terraform config against the *current* live instance (import existing resources, or accept a one-time cutover to a Terraform-created replacement).

## Alternatives considered

- **Keep manual console provisioning (status quo)**: zero new tooling, but no reproducibility or DR story, and the backup-bucket automation gap stays open indefinitely. Rejected — this is exactly the kind of undocumented, unenforced infra the project is trying to move away from post-rewrite.
- **Pulumi**: same IaC benefits, real programming language instead of HCL. Rejected for this scope — a single instance + firewall + one bucket doesn't need general-purpose-language complexity, and Terraform's Scaleway provider has better community coverage than Pulumi's.
- **Ansible instead of Terraform**: Ansible is configuration management (install Docker, push config), not resource provisioning (create the instance itself) — it solves a different problem. Could be layered on top of Terraform later for the Docker-install step currently done by hand; out of scope for this ADR.
- **Bring the app-deploy workflow into Terraform too** (e.g. `terraform apply` also runs `docker compose up`): rejected — conflates infrequent infra changes with frequent app deploys, and breaks the existing manual-only deploy gate (no auto-deploy on `main`) that's already an accepted convention.

## Amendment (2026-07-02) — scope narrowed to Object Storage only

Before first apply, the scope was reconsidered and narrowed: Terraform manages
**only the Object Storage layer** (`storage.tf` — the backup bucket and its
lifecycle/retention rules). Compute, network, and DNS stay hand-provisioned,
now against an exact written spec: `infra/README.md` "First-time setup" step 1
carries the full instance/security-group runbook, and `infra/cloud-init.yaml`
(moved out of the Terraform module) is pasted as user-data at instance creation.

Why the original scope lost on reflection:

- **The estate is one box changing a few times a year.** IaC value compounds
  with resource count and change frequency; both are deliberately minimal here
  (single-box compose, staging deferred, single Postgres per ADR 0001) — and
  the DR delta is small because steps 3+ (Supabase, env files, compose, DNS)
  stay manual either way. The runbook is needed regardless; Terraform would
  only replace ~20 console-minutes of it, on a once-in-years event.
- **The cutover problem.** The production box already exists, hand-built.
  Until it is imported (fiddly, and the first `plan` against imported reality
  is a minefield) or destroyed and recreated (downtime for no functional gain),
  `compute.tf` would describe a box that doesn't exist — a repo that lies about
  how prod was made is worse than one that says "by hand, here's the exact spec".
- **Solo-operator drift is not hypothetical.** A console hotfix followed months
  later by a `terraform plan` that proposes to "correct" it — where
  instance-level corrections can mean **replacement** — is the standard way
  stale IaC destroys a production box. Avoiding that requires a
  never-touch-the-console discipline that solo operation makes unrealistic.
- **The bucket is where config-as-code genuinely pays**: its lifecycle rules
  are the data-retention policy (invisible console state otherwise), it is
  greenfield (no import), nobody hotfixes lifecycle rules at 2 a.m., and the
  blast radius of an apply is nil.

Consequences of the narrowing: the remote-state backend (and its
chicken-and-egg bootstrap bucket, flagged in the negatives above) is dropped —
state is local and gitignored, acceptable because losing it costs one
`terraform import` of a single bucket.

**Revisit triggers** (re-open toward the original full scope): a second box
(staging), the estate passing ~10 resources, or the first console fat-finger
that a `terraform plan` diff would have caught.

## Amendment (2026-10-03) — scope widened again: the whole Scaleway side of the box

The hand-built box from July no longer exists and the Scaleway account is
empty. That removes the two objections that carried the narrowing:

- **No cutover problem.** Nothing has to be imported, and no config describes
  a box that was made some other way. The first apply is greenfield.
- **The runbook was the only record, and the box it described is gone.** The
  next box has to be built from the repo anyway.

Two things are new:

- **The box gets its own restricted API key.** Until now the runtime used a
  personal key with the full rights of its owner. An IAM application with a
  policy limited to Generative APIs and Object Storage objects is three
  resources that are easy to get wrong by hand and easy to read as code.
- **The repo is being open-sourced.** Someone else must be able to stand up
  the same box from what is checked in.

Terraform (run with OpenTofu) now manages: the SSH keys, the reserved IP, the
security group, the instance (GP1-XS, Ubuntu 24.04, `infra/cloud-init.yaml`
as first-boot user-data), the runtime IAM application / policy / API key, and
the backup bucket. Not in Terraform: DNS (not at Scaleway), and everything on
the box — Supabase install, env files, compose — which `infra/bootstrap.sh`
sets up (`infra/README.md`, "First deploy").

The drift risk named above is real, so the config carries guards rather than
relying on discipline:

- the instance is `protected` — the Scaleway API refuses to delete it, so a
  plan that would replace the box fails instead of destroying it;
- the root volume keeps `delete_on_termination = false`;
- changes to `cloud-init.yaml` are ignored for an existing instance.

State stays local and gitignored, for the bootstrap reason given in the first
amendment. It now contains the runtime key's secret, so it must never be
committed or shared. Losing it costs a handful of `import` commands and a
replaced key (`infra/terraform/README.md`).
