# ADR 0012 — Terraform for Scaleway infra provisioning.
#
# Provider version verified against the terraform-provider-scaleway GitHub
# releases (latest was v2.77.1 as of 2026-06-26) — re-check before bumping
# the upper bound.

terraform {
  required_version = ">= 1.6.1" # needed for native S3-backend state locking (use_lockfile)

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.77"
    }
  }

  # Remote state on Scaleway Object Storage (S3-compatible). The bucket named
  # below must already exist before `terraform init` — see README.md
  # "Bootstrap" for the one-time manual step (chicken-and-egg: this config
  # can't create the bucket it stores its own state in).
  backend "s3" {
    bucket                      = "redreamai-terraform-state"
    key                         = "prod/terraform.tfstate"
    region                      = "fr-par"
    endpoint                    = "https://s3.fr-par.scw.cloud"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    force_path_style            = true
    use_lockfile                = true # native state locking (Terraform >= 1.6.1) — no DynamoDB equivalent needed
  }
}
