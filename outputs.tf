output "ipv4_address" {
  description = "Public IPv4 address of the server (null when server is inactive)."
  value       = var.server_active ? hcloud_server.dev[0].ipv4_address : null
}

output "ssh_user" {
  description = "Username for SSH access."
  value       = var.dev_username
}

output "ssh_private_key_path" {
  description = "Path to local SSH private key."
  value       = local.ssh_private_key_path
}

output "volume_id" {
  description = "Hetzner volume ID."
  value       = hcloud_volume.dev.id
}

output "volume_linux_device" {
  description = "Linux device path for the volume."
  value       = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.dev.id}"
}

output "server_status" {
  description = "Whether the server is currently active."
  value       = var.server_active ? "running" : "destroyed"
}

output "github_ssh_private_key" {
  description = "Private key for GitHub access on the server."
  value       = tls_private_key.github.private_key_openssh
  sensitive   = true
}

output "github_ssh_public_key" {
  description = "Public key registered with GitHub."
  value       = tls_private_key.github.public_key_openssh
}
