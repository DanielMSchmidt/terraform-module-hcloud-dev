locals {
  ssh_public_key       = trimspace(file(pathexpand(var.ssh_public_key_path)))
  ssh_private_key_path = trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")
}

# --- Persistent resources (survive server destruction) ---

resource "hcloud_ssh_key" "dev" {
  name       = "${var.name}-ssh-key"
  public_key = local.ssh_public_key
}

resource "hcloud_firewall" "dev" {
  name = "${var.name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_volume" "dev" {
  name     = "${var.name}-data"
  location = var.location
  size     = var.volume_size
  format   = "ext4"
}

# --- Ephemeral resources (created/destroyed daily) ---

resource "hcloud_server" "dev" {
  count = var.server_active ? 1 : 0

  name        = var.name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.dev.id]

  firewall_ids = [hcloud_firewall.dev.id]

  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    dev_username   = var.dev_username
    ssh_public_key = local.ssh_public_key
  })
}

resource "hcloud_volume_attachment" "dev" {
  count = var.server_active ? 1 : 0

  volume_id = hcloud_volume.dev.id
  server_id = hcloud_server.dev[0].id
  automount = false
}
