variable "project_id" {
  description = "Scaleway project ID to create resources in."
  type        = string
}

variable "region" {
  description = "Scaleway region for region-scoped resources (Object Storage bucket)."
  type        = string
  default     = "fr-par"
}

variable "backup_bucket_name" {
  description = "Globally-unique Scaleway Object Storage bucket name for Postgres backups (infra/backup/README.md)."
  type        = string
  default     = "redreamai-backups"
}
