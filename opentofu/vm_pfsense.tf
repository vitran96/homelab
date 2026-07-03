# ── pfSense ───────────────────────────────────────────────────────────────────
# IP: 192.168.1.151 (LAN — set manually during install)
# No cloud-init: install interactively via Proxmox console, then set started=true
# The ISO is uploaded automatically by Terraform from your local machine.
# ─────────────────────────────────────────────────────────────────────────────

# This resource uploads the pfSense ISO from your local machine to the
# 'local' storage pool on Proxmox. This avoids manual uploads.
resource "proxmox_virtual_environment_file" "pfsense_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  source_file {
    path = var.pfsense_iso_path
  }
}

# resource "proxmox_virtual_environment_file" "pfsense_config" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = var.proxmox_node

#   source_file {
#     path = "./config.xml" # or var.pfsense_config_path
#   }
# }

resource "proxmox_virtual_environment_vm" "pfsense" {
  name        = "pfsense"
  description = "pfSense firewall/router"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base        # 200
  on_boot     = true
  started     = true

  cpu {
    cores = 1
    type  = "host"
  }

  memory {
    dedicated = 512
  }

  # WAN NIC
  # network_device {
  #   bridge = var.network_bridge_wan
  #   model  = "virtio"
  # }

  # LAN NIC
  network_device {
    bridge = var.network_bridge_lan
    model  = "virtio"
  }

  # NOTE: pfSense does not support cloud-init.
  # Must config manually or via config.xml
  # initialization {
  #   # ip_config ignored for proxmox
  #   ip_config {
  #     ipv4 {
  #       address = var.pfsense_ip
  #       gateway = var.network_gateway
  #     }
  #   }
  #   dns {
  #     servers = var.pfsense_dns_servers
  #   }
  #   # SSH key is not used by pfSense by default.
  #   user_account { keys = [var.ssh_public_key] }
  # }

  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = 10
    file_format  = "raw"
  }

  cdrom {
    # enabled   = true
    file_id   = proxmox_virtual_environment_file.pfsense_iso.id
    interface = "ide2"
  }

  # boot_order = ["ide2", "virtio0"]
  boot_order = ["virtio0"]

  operating_system {
    type = "other"
  }

  agent { enabled = false } # QEMU Guest Agent is not installed by default

  lifecycle {
    ignore_changes = [cdrom]
  }
}
