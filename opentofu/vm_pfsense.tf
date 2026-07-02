# ── pfSense ───────────────────────────────────────────────────────────────────
# IP: 192.168.1.151 (LAN — set manually during install)
# No cloud-init: install interactively via Proxmox console, then set started=true
# Pre-req: upload pfSense ISO → Proxmox UI → local → ISO Images
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "pfsense" {
  name        = "pfsense"
  description = "pfSense firewall/router — 192.168.1.151"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base        # 200
  on_boot     = true
  started     = false                # flip to true after ISO install

  cpu {
    cores = 1
    type  = "host"
  }

  memory {
    dedicated = 512
  }

  # WAN NIC
  network_device {
    bridge = var.network_bridge_wan
    model  = "virtio"
  }

  # LAN NIC
  network_device {
    bridge = var.network_bridge_lan
    model  = "virtio"
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = 10
    file_format  = "raw"
  }

  cdrom {
    # enabled   = true
    file_id   = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
    interface = "ide2"
  }

  boot_order = ["virtio0", "ide2"]

  operating_system {
    type = "other"
  }

  lifecycle {
    ignore_changes = [cdrom]
  }
}
