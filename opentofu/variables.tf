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

# ── Network ───────────────────────────────────────────────────────────────────
variable "network_bridge_wan" {
  description = "Bridge facing WAN/internet (pfSense WAN NIC)"
  type        = string
  default     = "vmbr0"
}

variable "network_bridge_lan" {
  description = "Bridge for internal/LAN traffic (all other VMs)"
  type        = string
  default     = "vmbr1"
}

variable "network_gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers injected via cloud-init"
  type        = list(string)
  default     = ["192.168.1.1", "1.1.1.1"]
}

# ── Storage ───────────────────────────────────────────────────────────────────
variable "storage_pool" {
  description = "Proxmox storage pool for VM disks (e.g. local-lvm, nvme-pool)"
  type        = string
  default     = "local-lvm"
}

# ── Templates ─────────────────────────────────────────────────────────────────
variable "ubuntu_template_vmid" {
  description = "VMID of your Ubuntu 22.04 cloud-init template (see README)"
  type        = number
  default     = 9000
}

# ── SSH ───────────────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH public key injected into VMs via cloud-init"
  type        = string
}

#  type        = string
#  sensitive   = true
#  default     = "ChangeMe1234!"
#}

# ── VMID base ─────────────────────────────────────────────────────────────────
variable "vmid_base" {
  description = "Starting VMID: pfsense=base, jenkins=+1, openclaw=+2, k3s=+3"
  type        = number
  default     = 200
}

# ── k3s cluster sizing ────────────────────────────────────────────────────────
variable "k3s_worker_count" {
  description = "Number of k3s worker nodes to create (IPs start at 192.168.1.157)"
  type        = number
  default     = 3
}

variable "k3s_worker_cores" {
  description = "vCPU count per worker node"
  type        = number
  default     = 4
}

variable "k3s_worker_memory_mb" {
  description = "RAM in MB per worker node"
  type        = number
  default     = 8192
}

variable "k3s_worker_disk_gb" {
  description = "Disk size in GB per worker node"
  type        = number
  default     = 60
}

# ── Rancher ───────────────────────────────────────────────────────────────────
#   description = "Initial Rancher admin password — change on first login"
#   type        = string
#   sensitive   = true
#   default     = "ChangeMe1234!"
# }
