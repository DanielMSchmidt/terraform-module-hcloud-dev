variable "server_active" {
  description = "Whether the server should exist. Set to false to destroy the server while keeping the volume."
  type        = bool
  default     = true
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "dev"

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
  description = "Hetzner Cloud server type (e.g. cpx22, cpx32, ccx13, ccx23)."
  type        = string
  default     = "cpx22"
}

variable "image" {
  description = "Server OS image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "volume_size" {
  description = "Persistent volume size in GB."
  type        = number
  default     = 50

  validation {
    condition     = var.volume_size >= 10
    error_message = "volume_size must be at least 10 GB."
  }
}

variable "ssh_public_key_path" {
  description = "Path to local SSH public key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "github_token" {
  description = "GitHub personal access token for registering the server SSH key. Leave empty to skip."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dotfiles_repo" {
  description = "Chezmoi dotfiles repo (e.g. 'danielmschmidt/dotfiles'). When set, installs fish + chezmoi and applies dotfiles on the server."
  type        = string
  default     = ""
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
