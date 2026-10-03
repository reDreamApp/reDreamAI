# Backup bucket. Its lifecycle rules ARE the retention policy: nightly/7-day,
# weekly/4-week, monthly/12-month. The backup job (infra/backup/) only uploads
# pg_dump output under the matching nightly/, weekly/, monthly/ prefix.

resource "scaleway_object_bucket" "backups" {
  name   = var.backup_bucket_name
  region = var.region

  lifecycle_rule {
    id      = "nightly"
    prefix  = "nightly/"
    enabled = true
    expiration {
      days = 7
    }
  }

  lifecycle_rule {
    id      = "weekly"
    prefix  = "weekly/"
    enabled = true
    expiration {
      days = 28
    }
  }

  lifecycle_rule {
    id      = "monthly"
    prefix  = "monthly/"
    enabled = true
    expiration {
      days = 365
    }
  }
}
