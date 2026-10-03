output "server_ip" {
  description = "Reserved public IPv4 of the box: DNS A records and SCALEWAY_HOST point here."
  value       = scaleway_instance_ip.app.address
}

output "test_domain" {
  description = "Wildcard hostname that resolves to the box without owning a domain (DOMAIN for bootstrap.sh; its supabase. and langfuse. subdomains resolve too)."
  value       = "${replace(scaleway_instance_ip.app.address, ".", "-")}.sslip.io"
}

output "project_id" {
  description = "Project the runtime key is restricted to (SCALEWAY_PROJECT_ID in ai.env)."
  value       = var.project_id
}

output "runtime_access_key" {
  description = "Access key of the restricted runtime key (AWS_ACCESS_KEY_ID in backup.env)."
  value       = scaleway_iam_api_key.runtime.access_key
}

output "runtime_secret_key" {
  description = "Secret of the restricted runtime key (SCALEWAY_API_KEY in ai.env, AWS_SECRET_ACCESS_KEY in backup.env)."
  value       = scaleway_iam_api_key.runtime.secret_key
  sensitive   = true
}

output "backup_bucket_name" {
  description = "Object Storage bucket for Postgres backups (BACKUP_BUCKET in the host's backup.env)."
  value       = scaleway_object_bucket.backups.name
}

output "backup_s3_endpoint" {
  description = "S3-compatible endpoint for the bucket's region (S3_ENDPOINT in backup.env)."
  value       = "https://s3.${var.region}.scw.cloud"
}
