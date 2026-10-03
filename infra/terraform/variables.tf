variable "project_id" {
  description = "Scaleway project ID to create resources in."
  type        = string
}

variable "ssh_public_keys" {
  description = "SSH public keys allowed to log in as root, as name => key. Include your own key and the public half of the GitHub Actions deploy key (SCALEWAY_SSH_KEY)."
  type        = map(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one SSH public key is needed, or nobody can log in to the instance."
  }
}

variable "region" {
  description = "Scaleway region for region-scoped resources (Object Storage bucket)."
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone for the instance, its IP and its security group."
  type        = string
  default     = "fr-par-1"
}

variable "instance_type" {
  description = "Instance commercial type. GP1-XS = 4 vCPU / 16 GB RAM."
  type        = string
  default     = "GP1-XS"
}

variable "root_volume_size_gb" {
  description = "Root volume size in GB (local SSD, billed on top of the instance; GP1-XS allows up to 150)."
  type        = number
  default     = 50
}

variable "ssh_allowed_cidrs" {
  description = "Source ranges allowed to reach SSH. Leave open if GitHub-hosted runners deploy to the box (their addresses are not fixed); login is key-only either way."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backup_bucket_name" {
  description = "Globally-unique Scaleway Object Storage bucket name for Postgres backups (infra/backup/README.md)."
  type        = string
  default     = "redreamai-backups"
}
