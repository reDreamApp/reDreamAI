output "instance_public_ip" {
  description = "Public IP to point DNS A records at (infra/README.md step 7)."
  value       = scaleway_instance_ip.prod.address
}

output "backup_bucket_name" {
  description = "Object Storage bucket for Postgres backups."
  value       = scaleway_object_bucket.backups.name
}
