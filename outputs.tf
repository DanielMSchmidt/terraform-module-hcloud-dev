output "server_id" {
  description = "ID of the created Hetzner Cloud server."
  value       = hcloud_server.this.id
}

output "server_name" {
  description = "Name of the created server."
  value       = hcloud_server.this.name
}

output "ipv4_address" {
  description = "Public IPv4 address of the development server."
  value       = hcloud_server.this.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 network assigned to the server."
  value       = hcloud_server.this.ipv6_address
}

output "ssh_user" {
  description = "Username to use for SSH access."
  value       = var.dev_username
}

output "ssh_command" {
  description = "SSH command for connecting to the development environment."
  value       = "ssh ${var.dev_username}@${hcloud_server.this.ipv4_address}"
}

output "firewall_id" {
  description = "Firewall ID when enable_firewall is true; otherwise null."
  value       = var.enable_firewall ? hcloud_firewall.this[0].id : null
}
