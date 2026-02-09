provider "hcloud" {
  token = var.hcloud_token
}

module "go_dev" {
  source = "../.."

  name                = "go-dev"
  location            = "fsn1"
  server_type         = "cpx42"
  image               = "ubuntu-24.04"
  ssh_public_key_path = var.ssh_public_key_path

  dev_username = "dev"
  go_version   = "1.24.0"

  # Replace with your own fixed public IP/CIDR.
  ssh_allowed_cidrs = ["0.0.0.0/0", "::/0"]

  labels = {
    project = "golang-dev"
    env     = "development"
  }
}

output "ssh_command" {
  value = module.go_dev.ssh_command
}

output "server_ipv4" {
  value = module.go_dev.ipv4_address
}
