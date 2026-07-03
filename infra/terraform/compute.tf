# Replaces infra/README.md "First-time setup" steps 1-2 (provision the
# instance, install Docker). Steps 3 onward (Supabase install, env files,
# DNS, `docker compose up`) are unchanged and still manual — see ADR 0012.

data "scaleway_instance_image" "ubuntu" {
  name = var.image_name
  zone = var.zone
}

resource "scaleway_instance_server" "prod" {
  name              = var.instance_name
  type              = var.instance_type
  image             = data.scaleway_instance_image.ubuntu.id
  zone              = var.zone
  ip_id             = scaleway_instance_ip.prod.id
  security_group_id = scaleway_instance_security_group.prod.id

  root_volume {
    size_in_gb            = var.root_volume_size_gb
    delete_on_termination = false
  }

  user_data = {
    cloud-init = file("${path.module}/cloud-init.yaml")
  }

  tags = ["redreamai", "production"]
}
