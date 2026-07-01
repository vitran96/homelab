# ── Distribution (OCI Container Registry) ────────────────────────────────────
# IP: 192.168.1.154  |  API: http://192.168.1.154:5000
# Bare binary, no Docker. Pure storage I/O — intentionally separate from k3s.
#
# Push an image:
#   docker tag myapp:latest 192.168.1.154:5000/myapp:latest
#   docker push 192.168.1.154:5000/myapp:latest
#
# k3s integration — add to /etc/rancher/k3s/registries.yaml on master:
#   mirrors:
#     "192.168.1.154:5000":
#       endpoint:
#         - "http://192.168.1.154:5000"
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "registry" {
  name        = "registry"
  description = "Distribution container registry — 192.168.1.154"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 3   # 203
  on_boot     = true
  started     = true

  clone {
    vm_id = var.ubuntu_template_vmid
    full  = true
  }

  cpu {
    cores = 1
    limit = 50
    units = 50
    type  = "host"
  }

  memory {
    dedicated = 512
  }

  network_device {
    bridge = var.network_bridge_lan
    model  = "virtio"
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 80
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.154/24"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
    user_data_file_id = proxmox_virtual_environment_file.registry_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "registry_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "registry-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - curl

      runcmd:
        - curl -fsSL https://github.com/distribution/distribution/releases/latest/download/registry_linux_amd64 -o /usr/local/bin/registry
        - chmod +x /usr/local/bin/registry
        - adduser registry --gecos "" --disabled-password --home /opt/registry
        - mkdir -p /opt/registry/data
        - |
          cat > /opt/registry/config.yml <<CFG
          version: 0.1
          log:
            level: info
          storage:
            filesystem:
              rootdirectory: /opt/registry/data
            delete:
              enabled: true
          http:
            addr: :5000
            headers:
              X-Content-Type-Options: [nosniff]
          health:
            storagedriver:
              enabled: true
              interval: 10s
              threshold: 3
          CFG
        - chown -R registry:registry /opt/registry
        - |
          cat > /etc/systemd/system/registry.service <<SERVICE
          [Unit]
          Description=Distribution Container Registry
          After=network.target
          [Service]
          Type=simple
          User=registry
          ExecStart=/usr/local/bin/registry serve /opt/registry/config.yml
          Restart=on-failure
          RestartSec=5
          [Install]
          WantedBy=multi-user.target
          SERVICE
        - systemctl daemon-reload
        - systemctl enable --now registry
        - echo "==> Registry ready at http://192.168.1.154:5000"
    EOT
  }
}
