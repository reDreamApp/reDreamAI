# Firewall + public IP for the production instance. Port list matches the
# manual "Configure SSH, firewall to allow 22 / 80 / 443" step this replaces
# (infra/README.md, "First-time setup" step 1).

resource "scaleway_instance_ip" "prod" {
  zone = var.zone
}

resource "scaleway_instance_security_group" "prod" {
  name = "${var.instance_name}-sg"
  zone = var.zone

  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    port     = 22
    ip_range = var.ssh_allowed_ip_range
  }

  inbound_rule {
    action = "accept"
    port   = 80
  }

  inbound_rule {
    action   = "accept"
    port     = 443
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    port     = 443
    protocol = "UDP" # HTTP/3 (QUIC) — Caddy's compose config binds 443/udp too
  }
}
