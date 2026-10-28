# The production box: one instance behind a reserved IP and a default-drop
# security group. What runs on it is described in infra/README.md.

# The box rebuilds root's authorized_keys from the project's IAM SSH keys at
# every boot, so keys added by hand on the box do not last. After adding a key
# here, run `scw-fetch-ssh-keys --upgrade` on the box (or reboot it).
resource "scaleway_iam_ssh_key" "admin" {
  for_each = var.ssh_public_keys

  name       = "redreamai-${each.key}"
  public_key = each.value
  project_id = var.project_id
}

# Reserved, so DNS survives a rebuild of the instance.
resource "scaleway_instance_ip" "app" {
  tags = ["redreamai"]
}

resource "scaleway_instance_security_group" "app" {
  name        = "redreamai-app"
  description = "SSH + HTTP/HTTPS (incl. HTTP/3) in, everything out."

  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  # Scaleway's default security also blocks OUTBOUND SMTP (25/465/587). The
  # moderation mail (ADR 0006) therefore needs a relay on another port, or
  # this set to false once Scaleway has unblocked SMTP for the account.
  enable_default_security = true

  dynamic "inbound_rule" {
    for_each = var.ssh_allowed_cidrs
    content {
      action   = "accept"
      protocol = "TCP"
      port     = 22
      ip_range = inbound_rule.value
    }
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 80
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 443
  }

  # HTTP/3: Caddy binds QUIC on 443/udp too.
  inbound_rule {
    action   = "accept"
    protocol = "UDP"
    port     = 443
  }
}

resource "scaleway_instance_server" "app" {
  name  = "redreamai-app"
  type  = var.instance_type
  image = "ubuntu_noble" # Ubuntu 24.04 LTS; cloud-init.yaml assumes it
  tags  = ["redreamai"]

  ip_id             = scaleway_instance_ip.app.id
  security_group_id = scaleway_instance_security_group.app.id

  # Installs Docker on first boot.
  cloud_init = file("${path.module}/../cloud-init.yaml")

  root_volume {
    volume_type = "l_ssd"
    size_in_gb  = var.root_volume_size_gb
    # Postgres lives on this volume: keep it if the instance is ever deleted.
    delete_on_termination = false
  }

  # The Scaleway API refuses to delete a protected instance, so a plan that
  # would replace the box fails instead of destroying it. Protection also
  # blocks stopping it, which a type change needs (var.protected).
  protected = var.protected

  lifecycle {
    # cloud-init only runs on first boot; editing the file later must not
    # stop/start a running box.
    ignore_changes = [cloud_init]
  }

  depends_on = [scaleway_iam_ssh_key.admin]
}
