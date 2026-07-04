# ADR 0012 (as amended 2026-07-02) — Terraform for Scaleway OBJECT STORAGE only.
# The compute/network layer is provisioned by hand per the runbook in
# infra/README.md ("First-time setup" step 1) + infra/cloud-init.yaml.
#
# Provider version verified against the terraform-provider-scaleway GitHub
# releases (latest was v2.77.1 as of 2026-06-26) — re-check before bumping
# the upper bound.

terraform {
  required_version = ">= 1.6"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.77"
    }
  }

  # State is LOCAL (gitignored), deliberately: with the scope narrowed to a
  # single bucket, a remote-state bucket would mean managing a second bucket
  # (plus its bootstrap and credentials) just to track one. Losing this state
  # is a non-event — recover with:
  #   terraform import scaleway_object_bucket.backups <region>/<bucket-name>
}
