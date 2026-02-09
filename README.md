# terraform-module-hcloud-dev

Terraform module for creating a Hetzner Cloud development server optimized for Go development, with SSH access using your local SSH key.

## Features

- Creates a single Hetzner Cloud server for development
- Registers your local SSH public key in Hetzner Cloud
- Optionally creates and attaches a firewall (SSH on port 22)
- Boots with cloud-init and installs a Go toolchain plus common development tools
- Creates a non-root development user (default: `dev`)

## Requirements

- Terraform `>= 1.6.0`
- Hetzner Cloud API token
- Local SSH public key (default: `~/.ssh/id_ed25519.pub`)

## Provider dev override (local provider build)

To force Terraform to use your local provider build at `/Users/danielschmidt/work/terraform-provider-hcloud`, create a CLI config file (for example `terraform.dev.tfrc`):

```hcl
provider_installation {
  dev_overrides {
    "hetznercloud/hcloud" = "/Users/danielschmidt/work/terraform-provider-hcloud"
  }

  direct {}
}
```

Then run Terraform with:

```bash
TF_CLI_CONFIG_FILE=$(pwd)/terraform.dev.tfrc terraform init
TF_CLI_CONFIG_FILE=$(pwd)/terraform.dev.tfrc terraform plan
TF_CLI_CONFIG_FILE=$(pwd)/terraform.dev.tfrc terraform apply
```

## Usage

```hcl
provider "hcloud" {
  token = var.hcloud_token
}

module "go_dev" {
  source = "../terraform-module-hcloud-dev"

  name                = "go-dev"
  location            = "fsn1"
  server_type         = "cx22"
  image               = "ubuntu-24.04"
  ssh_public_key_path = "~/.ssh/id_ed25519.pub"

  dev_username = "dev"
  go_version   = "1.24.0"

  # Best practice: restrict SSH to your own IP/CIDRs.
  ssh_allowed_cidrs = ["203.0.113.10/32"]

  labels = {
    project = "golang-dev"
    owner   = "daniel"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name prefix for resources. | `string` | `"go-dev"` | no |
| `location` | Hetzner Cloud location (`nbg1`, `fsn1`, `hel1`, `ash`, `hil`). | `string` | `"fsn1"` | no |
| `server_type` | Hetzner Cloud server type. | `string` | `"cx22"` | no |
| `image` | Server image. | `string` | `"ubuntu-24.04"` | no |
| `ssh_public_key` | SSH public key content; takes precedence over `ssh_public_key_path` if set. | `string` | `null` | no |
| `ssh_public_key_path` | Path to local SSH public key used when `ssh_public_key` is null. | `string` | `"~/.ssh/id_ed25519.pub"` | no |
| `dev_username` | Non-root Linux user for development. | `string` | `"dev"` | no |
| `go_version` | Go version installed from `go.dev`. | `string` | `"1.24.0"` | no |
| `enable_firewall` | Whether to create and attach a firewall for the server. | `bool` | `true` | no |
| `ssh_allowed_cidrs` | CIDR blocks allowed to access SSH (`TCP/22`). | `list(string)` | `["0.0.0.0/0", "::/0"]` | no |
| `labels` | Additional labels for created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `server_id` | ID of the created Hetzner Cloud server. |
| `server_name` | Name of the created server. |
| `ipv4_address` | Public IPv4 address. |
| `ipv6_address` | Public IPv6 network assigned to the server. |
| `ssh_user` | Username for SSH access. |
| `ssh_command` | Ready-to-use SSH command. |
| `firewall_id` | Firewall ID when enabled, otherwise `null`. |

## Security notes / best practices

- Set `ssh_allowed_cidrs` to your fixed public IP(s) instead of allowing all addresses.
- Prefer short-lived API tokens and keep them in environment variables.
- Do not use provider `dev_overrides` in production workflows.

## Example

See `/examples/basic` for a runnable example configuration.
