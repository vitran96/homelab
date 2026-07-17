# ── Proxmox connection ────────────────────────────────────────────────────────
variable "proxmox_endpoint" {
  description = "Full URL to the Proxmox API (e.g. https://192.168.1.10:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the form 'user@realm!tokenid=secret'"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (useful with self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user for Proxmox node (needed for snippet file uploads)"
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Target Proxmox node name (check with: pvesh get /nodes)"
  type        = string
  default     = "pve"
}

variable "host_private_key" {
  description = "Host private key for Proxmox"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# ── Network ───────────────────────────────────────────────────────────────────
# variable "network_bridge_wan" {
#   description = "Bridge facing WAN/internet (pfSense WAN NIC)"
#   type        = string
#   default     = "vmbr0"
# }

variable "network_bridge_lan" {
  description = "Bridge for internal/LAN traffic (all other VMs)"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.1.1"
}

variable "pfsense_dns_servers" {
  description = "DNS servers for pfSense firewall/router"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1", "192.168.1.1"]
}


variable "dns_servers" {
  description = "DNS servers injected via cloud-init"
  type        = list(string)
  default     = ["192.168.1.151", "192.168.1.1"]
}

variable "pfsense_ip" {
  description = "LAN IP for pfSense firewall/router"
  type        = string
  default     = "192.168.1.151"
}

# ── ISOs ──────────────────────────────────────────────────────────────────────
variable "pfsense_iso_path" {
  description = "Local path to the pfSense installer ISO file"
  type        = string
  default     = "./iso/pfsense.iso"
}

# ── Storage ───────────────────────────────────────────────────────────────────
variable "storage_pool" {
  description = "Proxmox storage pool for VM disks (e.g. local-lvm, nvme-pool)"
  type        = string
  default     = "local-lvm"
}

# ── Templates ─────────────────────────────────────────────────────────────────
variable "rocky_template_vmid" {
  description = "VMID of your Ubuntu 22.04 cloud-init template (see README)"
  type        = number
  default     = 9000
}

# ── SSH ───────────────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH public key injected into VMs via cloud-init"
  type        = string
}

# ── VMID base ─────────────────────────────────────────────────────────────────
variable "vmid_base" {
  description = "Starting VMID: pfsense=base, jenkins=+1, openclaw=+2, k3s=+3"
  type        = number
  default     = 200
}

# ── k3s cluster sizing ────────────────────────────────────────────────────────
# variable "k3s_worker_count" {
#   description = "Number of k3s worker nodes to create (IPs start at 192.168.1.157)"
#   type        = number
#   default     = 3
# }

# variable "k3s_worker_cores" {
#   description = "vCPU count per worker node"
#   type        = number
#   default     = 4
# }

# variable "k3s_worker_memory_mb" {
#   description = "RAM in MB per worker node"
#   type        = number
#   default     = 8192
# }

# variable "k3s_worker_disk_gb" {
#   description = "Disk size in GB per worker node"
#   type        = number
#   default     = 60
# }

variable "k3s_master_username" {
  description = "K3s master node username"
  type        = string
  default     = "k3s-master"
}

variable "k3s_master_password" {
  description = "K3s master node password"
  type        = string
  default     = "password123"
}

variable "k3s_master_ip" {
  description = "LAN IP for K3S firewall/router"
  type        = string
  default     = "192.168.1.153"
}

# ── ZeroTier ──────────────────────────────────────────────────────────────────

# variable "zerotier_network_id" {
#   description = "Your ZeroTier network ID"
#   type        = string
# }

variable "gitea_ip" {
  description = "LAN IP for Gitea firewall/router"
  type        = string
  default     = "192.168.1.152"
}

variable "gitea_username" {
  description = "Gitea VM username"
  type        = string
  default     = "gitea"
}

variable "gitea_password" {
  description = "Gitea VM password"
  type        = string
  default     = "password123"
}

variable "registry_ip" {
  description = "LAN IP for Gitea firewall/router"
  type        = string
  default     = "192.168.1.154"
}

variable "registry_username" {
  description = "Registry VM username"
  type        = string
  default     = "rocky"
}

variable "registry_password" {
  description = "Registry VM password"
  type        = string
  default     = "password123"
}