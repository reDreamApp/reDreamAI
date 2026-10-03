# OpenTofu / Terraform — the Scaleway side of the box

Creates everything Scaleway has to provide for one reDreamAI box (ADR 0012,
2026-10-03 amendment):

| File | Resources |
|---|---|
| `compute.tf` | SSH keys, reserved IPv4, security group (22/80/443 tcp + 443 udp in, rest dropped), the instance (GP1-XS, Ubuntu 24.04, Docker via `../cloud-init.yaml`) |
| `iam.tf` | The restricted **runtime key**: an IAM application that may call Generative APIs and read/write (not delete) Object Storage objects in the project |
| `storage.tf` | The backup bucket and its retention (lifecycle) rules |

It does **not** touch what runs on the box or DNS. The box is set up by
`../bootstrap.sh` (see `../README.md`, "First deploy").

## Usage

Commands are shown with `tofu`; `terraform` >= 1.6 works the same way.

```bash
# Admin credentials: SCW_ACCESS_KEY / SCW_SECRET_KEY, or ~/.config/scw/config.yaml.
# This key needs IAM, Instances and Object Storage rights; it stays on your laptop.
cp terraform.tfvars.example terraform.tfvars   # project_id + your SSH public key(s)
tofu init
tofu plan
tofu apply
```

GP1-XS is billed per hour from the moment it exists (about €68/month at the
2026-10 list price), plus the root volume and the IPv4 address.

## Outputs

Most of them are the inputs of `../bootstrap.sh` (`bootstrap.env`):

| Output | Goes to |
|---|---|
| `server_ip` | DNS A records; GitHub secret `SCALEWAY_HOST`; `ssh root@<ip>` |
| `test_domain` | `DOMAIN` while you have no DNS (an sslip.io name; its subdomains resolve to the box too) |
| `runtime_secret_key` | `SCALEWAY_API_KEY` |
| `project_id` | `SCALEWAY_PROJECT_ID` — the runtime key only works with the project in the URL |
| `runtime_access_key` | `BACKUP_ACCESS_KEY` |
| `backup_bucket_name`, `backup_s3_endpoint` | `BACKUP_BUCKET`, `S3_ENDPOINT` |

```bash
tofu output -raw runtime_secret_key   # sensitive: only printed when asked for by name
```

Check the runtime key once after the first apply:

```bash
curl -s "https://api.scaleway.ai/$(tofu output -raw project_id)/v1/models" \
  -H "Authorization: Bearer $(tofu output -raw runtime_secret_key)" | head -c 300
```

Without the project in the URL the same key gets `403`: the bare URL means the
organization's default project.

Rotate it with `tofu apply -replace=scaleway_iam_api_key.runtime`, then put the
new values into `bootstrap.env` on the box and run `bootstrap.sh` again.

## Guard rails

- The instance is `protected`: Scaleway refuses to delete it, so a plan that
  would **replace** the box (for example after changing the image or the zone)
  fails instead of destroying it. To remove the box on purpose, set `protected = false`,
  apply, then destroy.
- The root volume has `delete_on_termination = false`: it holds Postgres and
  survives the instance. After a deliberate destroy it is left behind as a
  detached volume that you delete (or reattach) yourself.
- Changes to `../cloud-init.yaml` are ignored for an existing instance;
  cloud-init only runs on first boot.
- The runtime key cannot delete objects. Backups expire through the bucket's
  lifecycle rules only.
- SSH keys reach the box through `ssh_public_keys` only: it rebuilds
  `authorized_keys` from the project's keys at every boot. After adding one,
  run `scw-fetch-ssh-keys --upgrade` on the box.

## State

Local and gitignored. **It contains the runtime key's secret** — never commit
or share `terraform.tfstate`. There is no remote backend on purpose: a state
bucket needs its own bootstrap and credentials to track one box.

If the state file is lost, re-import (IDs are in the Scaleway console) and
replace the key, whose secret cannot be read back:

```bash
tofu import scaleway_instance_ip.app             fr-par-1/<ip-id>
tofu import scaleway_instance_security_group.app fr-par-1/<security-group-id>
tofu import scaleway_instance_server.app         fr-par-1/<server-id>
tofu import scaleway_object_bucket.backups       fr-par/<bucket-name>
tofu import scaleway_iam_application.runtime     <application-id>
tofu import scaleway_iam_policy.runtime          <policy-id>
tofu import 'scaleway_iam_ssh_key.admin["laptop"]' <ssh-key-id>
tofu apply    # creates a fresh runtime key; delete the old one in the console
```
