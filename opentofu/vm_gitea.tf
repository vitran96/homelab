# ── Gitea ─────────────────────────────────────────────────────────────────────
# IP: 192.168.1.152  |  UI: http://192.168.1.152:3000
# Bare binary, no Docker. Stores repos in /opt/gitea/data.
# After deploy: visit http://192.168.1.152:3000 to complete first-run wizard.
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "gitea" {
  name        = "gitea"
  description = "Gitea Git server — 192.168.1.152"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 1   # 201
  on_boot     = true
  started     = true

  clone {
    vm_id = var.rocky_template_vmid
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
    size         = 60
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.152/24"
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
    user_data_file_id = proxmox_virtual_environment_file.gitea_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "gitea_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "gitea-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - curl
        - git
        - sqlite3

      runcmd:
        - adduser gitea --gecos "" --disabled-password --home /opt/gitea
        - mkdir -p /opt/gitea/data /opt/gitea/custom /opt/gitea/log
        - curl -fsSL https://dl.gitea.com/gitea/1.22.1/gitea-1.22.1-linux-amd64 -o /usr/local/bin/gitea
        - chmod +x /usr/local/bin/gitea
        - chown -R gitea:gitea /opt/gitea
        - |
          cat > /etc/systemd/system/gitea.service <<SERVICE
          [Unit]
          Description=Gitea
          After=network.target
          [Service]
          Type=simple
          User=gitea
          WorkingDirectory=/opt/gitea
          ExecStart=/usr/local/bin/gitea web --config /opt/gitea/custom/app.ini
          Restart=on-failure
          RestartSec=5
          Environment=HOME=/opt/gitea USER=gitea GITEA_WORK_DIR=/opt/gitea
          [Install]
          WantedBy=multi-user.target
          SERVICE
        - systemctl daemon-reload
        - systemctl enable --now gitea
        - echo "==> Gitea ready at http://192.168.1.152:3000 — finish setup via web UI"
    EOT
  }
}
