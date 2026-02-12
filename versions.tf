terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.45.0, < 2.0.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0.0, < 7.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "hcloud" {
  # Reads HCLOUD_TOKEN from environment automatically
}

provider "github" {
  token = var.github_token
}
