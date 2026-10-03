output "backup_bucket_name" {
  description = "Object Storage bucket for Postgres backups (BACKUP_BUCKET in the host's backup.env)."
  value       = scaleway_object_bucket.backups.name
}

output "backup_s3_endpoint" {
  description = "S3-compatible endpoint for the bucket's region (S3_ENDPOINT in backup.env)."
  value       = "https://s3.${var.region}.scw.cloud"
}
