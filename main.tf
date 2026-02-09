locals {
  ssh_public_key_resolved = trimspace(coalesce(var.ssh_public_key, file(pathexpand(var.ssh_public_key_path))))
  ssh_host_alias_resolved = trimspace(var.ssh_host_alias)
  ssh_private_key_path_resolved = var.ssh_private_key_path != null ? pathexpand(var.ssh_private_key_path) : (
    var.ssh_public_key == null && endswith(pathexpand(var.ssh_public_key_path), ".pub")
    ? trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")
    : null
  )

  common_labels = merge({
    managed_by  = "terraform"
    module      = "hcloud-dev"
    environment = "development"
  }, var.labels)
}

resource "hcloud_ssh_key" "this" {
  name       = "${var.name}-ssh-key"
  public_key = local.ssh_public_key_resolved
  labels     = local.common_labels
}

resource "hcloud_firewall" "this" {
  count = var.enable_firewall ? 1 : 0

  name   = "${var.name}-fw"
  labels = local.common_labels

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
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

resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.this.id]
  labels      = local.common_labels

  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    dev_username   = var.dev_username
    go_version     = var.go_version
    ssh_public_key = local.ssh_public_key_resolved
  })

  firewall_ids = var.enable_firewall ? [hcloud_firewall.this[0].id] : []
}

action "hcloud_server_poweron" "server" {
    config {
        server_id = hcloud_server.this.id
    }
}

action "hcloud_server_poweroff" "server" {
    config {
        server_id = hcloud_server.this.id
    }
}