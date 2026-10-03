# Terraform — Scaleway Object Storage only

Provisions **only the backup bucket** (+ its lifecycle/retention rules) — see
`storage.tf`. The compute instance, firewall, and DNS are provisioned by hand
per the runbook in `../README.md` ("First-time setup" step 1) with
`../cloud-init.yaml` as user-data.

Scope was narrowed on 2026-07-02 (ADR 0012 amendment): a one-box estate doesn't
repay instance-level IaC — the live box would need importing or recreating, and
solo-operator console hotfixes make state drift (and `plan`-proposed instance
replacement) a real footgun. The bucket is the piece where config-as-code
genuinely pays: greenfield (no import), zero blast radius, drift-immune, and
its lifecycle rules ARE the data-retention policy.

## Usage

```bash
export SCW_ACCESS_KEY=...        # IAM application key, not your personal key
export SCW_SECRET_KEY=...
cp terraform.tfvars.example terraform.tfvars   # fill in project_id
terraform init
terraform plan
terraform apply
```

Outputs feed the host's `backup.env` (see `../backup/README.md`):
`backup_bucket_name` → `BACKUP_BUCKET`, `backup_s3_endpoint` → `S3_ENDPOINT`.

## State

Local and gitignored — deliberate (see `versions.tf`). With one bucket under
management, a remote-state bucket would mean running a second bucket to track
the first. If the state file is ever lost:

```bash
terraform import scaleway_object_bucket.backups <region>/<bucket-name>
```

### ⚠️ Migrating from the pre-narrowing config (one-time)

If `terraform apply` was ever run with the ORIGINAL full-scope config (remote
S3 backend + compute/network resources), do this before the first plan against
the narrowed config — **resources that are in state but no longer in config
get PROPOSED FOR DESTRUCTION by `terraform plan`**:

```bash
terraform init -migrate-state        # pull state out of the old S3 backend
terraform state list                 # inspect what's tracked
# For anything that is NOT scaleway_object_bucket.backups (instance, IP,
# security group): remove it from state WITHOUT touching the real resource:
terraform state rm scaleway_instance_server.prod        # (if present)
terraform state rm scaleway_instance_ip.prod            # (if present)
terraform state rm scaleway_instance_security_group.prod # (if present)
terraform plan                       # must now show: no changes
```

If the bucket was instead created by hand (or the old config was never
applied), skip this — `terraform import` the bucket (command above) or just
`apply` greenfield.

## Revisit triggers (full IaC again)

Re-open the ADR if any of these happen: a second box (staging), the estate
passing ~10 resources, or a console fat-finger that a `terraform plan` diff
would have caught.
