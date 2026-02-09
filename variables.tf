variable "name" {
  description = "Name prefix for resources."
  type        = string
  default     = "go-dev"

  validation {
    condition     = length(var.name) > 0
    error_message = "name must not be empty."
  }
}

variable "location" {
  description = "Hetzner Cloud location (nbg1, fsn1, hel1, ash, hil)."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cpx42"
}

variable "image" {
  description = "Server image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key" {
  description = "SSH public key content. If set, this value is used instead of ssh_public_key_path."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ssh_public_key == null || trimspace(var.ssh_public_key) != ""
    error_message = "ssh_public_key cannot be empty when provided."
  }
}

variable "ssh_public_key_path" {
  description = "Path to local SSH public key used for login when ssh_public_key is null."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to local SSH private key for generated SSH config output. If null, the module infers it from ssh_public_key_path when possible."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ssh_private_key_path == null || trimspace(var.ssh_private_key_path) != ""
    error_message = "ssh_private_key_path cannot be empty when provided."
  }
}

variable "ssh_host_alias" {
  description = "Host alias used in generated SSH config output."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^\\S+$", var.ssh_host_alias))
    error_message = "ssh_host_alias must not contain whitespace."
  }
}

variable "ssh_forward_agent" {
  description = "Whether to enable SSH agent forwarding in generated SSH config output."
  type        = bool
  default     = true
}

variable "dev_username" {
  description = "Non-root Linux user for development."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.dev_username))
    error_message = "dev_username must be a valid Linux username."
  }
}

variable "go_version" {
  description = "Go version installed from go.dev (for example 1.24.0)."
  type        = string
  default     = "1.25.5"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.go_version))
    error_message = "go_version must match MAJOR.MINOR or MAJOR.MINOR.PATCH."
  }
}

variable "enable_firewall" {
  description = "Whether to create and attach a firewall for the server."
  type        = bool
  default     = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to access SSH (TCP/22)."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "ssh_allowed_cidrs must only contain valid IPv4 or IPv6 CIDR values."
  }
}

variable "labels" {
  description = "Additional labels to attach to created resources."
  type        = map(string)
  default     = {}
}
