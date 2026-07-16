# ── Rocky Linux 9 Cloud-Init Template (base image for all cloned VMs) ─────────
# VM ID: var.rocky_template_vmid (9000)
# Equivalent to pfsense_iso, but downloads straight from URL — no local file needed.
# Any VM (registry, k3s nodes, etc.) can clone from this by referencing:
#   clone { vm_id = proxmox_virtual_environment_vm.rocky_template.vm_id }
# ─────────────────────────────────────────────────────────────────────────────

# Downloads the Rocky Linux 9 GenericCloud image directly onto the Proxmox node.
resource "proxmox_download_file" "rocky_cloud_image" {
  content_type = "import" # required for disk import (PVE 8.1+)
  datastore_id = "local"
  node_name    = var.proxmox_node
  # url          = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  url          = "https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2"
  file_name    = "rocky-9-genericcloud-base.qcow2"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "rocky_template" {
  name      = "rocky-9-template"
  node_name = var.proxmox_node
  vm_id     = var.rocky_template_vmid # 9000
  template  = true                    # marks this VM as a clone source, not a running VM

  cpu {
    cores = 1
    type  = "host"
  }

  memory {
    dedicated = 1024
  }

  network_device {
    bridge = var.network_bridge_lan
    model  = "virtio"
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    import_from  = proxmox_download_file.rocky_cloud_image.id
    size = 10
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  # Placeholder cloud-init so the template has an initialization block ready;
  # actual IP/user settings get overridden by whatever clones this template.
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # Serial console — cloud images expect this, not a default VGA display.
  # Also avoids the "could not read from cdrom" boot issue some hit with Rocky images.
  serial_device {}

  operating_system {
    type = "l26"
  }

  agent { enabled = true }

  lifecycle {
    ignore_changes = [network_device] # don't fight manual tweaks made post-template-creation
  }
}
