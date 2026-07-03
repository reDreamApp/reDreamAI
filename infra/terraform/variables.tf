variable "project_id" {
  description = "Scaleway project ID to create resources in."
  type        = string
}

variable "zone" {
  description = "Scaleway zone for the instance, IP, and security group."
  type        = string
  default     = "fr-par-1"
}

variable "region" {
  description = "Scaleway region for region-scoped resources (Object Storage bucket)."
  type        = string
  default     = "fr-par"
}

variable "instance_name" {
  description = "Name of the production Scaleway instance."
  type        = string
  default     = "redreamai-prod"
}

variable "instance_type" {
  description = "Scaleway commercial instance type. GP1-S (4 vCPU / 8 GB RAM) per infra/README.md."
  type        = string
  default     = "GP1-S"
}

variable "image_name" {
  description = "Marketplace image name resolved via the scaleway_instance_image data source. If this doesn't resolve, check the exact current label with `scw marketplace image list name=ubuntu`."
  type        = string
  default     = "Ubuntu 24.04 Noble Numbat"
}

variable "root_volume_size_gb" {
  description = "Root volume size in GB."
  type        = number
  default     = 50
}

variable "ssh_allowed_ip_range" {
  description = "CIDR allowed to reach port 22. Matches the current (unrestricted) manual setup by default — tighten to your IP/VPN range before applying if you want to harden this."
  type        = string
  default     = "0.0.0.0/0"
}

variable "backup_bucket_name" {
  description = "Globally-unique Scaleway Object Storage bucket name for Postgres backups (infra/README.md \"Backups\" section)."
  type        = string
  default     = "redreamai-backups"
}
