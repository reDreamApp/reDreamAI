# ADR 0012 (as amended 2026-10-03) — the whole Scaleway side of the box:
# SSH keys, reserved IP, security group, instance, runtime API key, backup
# bucket. What runs on the box is set up by infra/bootstrap.sh; DNS stays
# manual (infra/README.md, "First deploy").
#
# The lock file pins the provider version the box was created with (2.84.0,
# 2026-10-03). Re-check the provider's release notes before bumping the upper
# bound.

terraform {
  required_version = ">= 1.6"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.77"
    }
  }

  # State is LOCAL and gitignored. It holds the runtime API key's secret
  # (iam.tf), so never commit or share it. A remote-state bucket would need
  # its own bootstrap and credentials to track one box, so it stays out. If
  # the state is lost, import the resources (README.md) and replace the key.
}
