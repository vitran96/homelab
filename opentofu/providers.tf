terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  # Optional: use a local state file for homelab
  # backend "s3" { ... }  # or "http" for Terraform Cloud / GitLab
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint   # e.g. "https://192.168.1.10:8006"
  api_token = var.proxmox_api_token # e.g. "root@pam!opentofu=<uuid>"
  insecure  = var.proxmox_insecure  # set true if using self-signed cert

  ssh {
    agent    = false
    username = var.proxmox_ssh_user
    private_key = file(pathexpand(var.host_private_key))
  }
}
