# Terraform — Scaleway infra provisioning

Provisions the Scaleway resource layer only: compute instance, firewall, backup
bucket. It does **not** deploy the app — that's still `infra/docker-compose.yml`
via `.github/workflows/deploy.yml`, unchanged. See ADR 0012
(`docs/decisions/0012-terraform-scaleway.md`) for the full reasoning.

## Bootstrap (one-time, before the first `terraform init`)

This config stores its own state in a Scaleway Object Storage bucket, which
means that bucket can't be created by this config (chicken-and-egg). Create
it once, by hand:

```bash
scw object bucket create name=redreamai-terraform-state region=fr-par
```

Enable versioning on it (console or `scw` CLI) so a corrupted state write is
recoverable.

Then export credentials for a Scaleway API key (IAM application scoped to
this project, not your personal key, if you want to be tidy about it):

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...
export SCW_DEFAULT_PROJECT_ID=...
```

## First apply

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in project_id at minimum
terraform init
terraform plan
terraform apply
```

Take the `instance_public_ip` output and continue from `infra/README.md`
step 3 onward (Supabase install, env files, DNS, `docker compose up`).

## Adopting the existing hand-provisioned instance

If a Scaleway instance from the old manual process is already running,
prefer importing it over recreating it (avoids downtime and TLS
re-issuance):

```bash
terraform import scaleway_instance_server.prod <zone>/<server-id>
terraform import scaleway_instance_ip.prod <zone>/<ip-id>
terraform import scaleway_instance_security_group.prod <zone>/<security-group-id>
terraform plan   # review the diff against the existing resource before applying anything
```

If the drift is too large to reconcile cleanly, the alternative is a
one-time cutover: `terraform apply` to create a fresh instance, re-run
`infra/README.md` steps 3+ on it, move DNS over, then decommission the old
box.

## Notes

- `image_name` (`variables.tf`) is resolved via a data source lookup, not a
  hardcoded image ID. If it fails to resolve, check the exact current label
  with `scw marketplace image list name=ubuntu`.
- Default SSH login on Scaleway's Ubuntu marketplace images is `root` via
  your account's registered SSH key — the cloud-init here doesn't create a
  separate user.
- `ssh_allowed_ip_range` defaults to `0.0.0.0/0`, matching the current
  unrestricted manual setup. Tighten it in `terraform.tfvars` if desired.
