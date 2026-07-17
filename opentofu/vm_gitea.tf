resource "proxmox_virtual_environment_vm" "gitea" {
  name        = "gitea"
  description = "Gitea Git server — ${var.gitea_ip}"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 1
  on_boot     = true
  started     = true

  clone {
    vm_id = var.rocky_template_vmid
    full  = true
  }

  cpu {
    cores = 2
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
    size         = 60
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.gitea_ip}/24"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_data_file_id = proxmox_virtual_environment_file.gitea_userdata.id
  }

  serial_device {}
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
      hostname: gitea-server
      chpasswd:
        list: |
          ${var.gitea_username}:${var.gitea_password}
        expire: False
      users:
        - default
        - name: ${var.gitea_username}
          groups:
            - sudo
          ssh_authorized_keys:
            - ${var.ssh_public_key}
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          shell: /bin/bash
      package_update: true
      package_upgrade: true
      packages:
        - curl
        - git
        - sqlite3
        - qemu-guest-agent

      runcmd:
        - adduser ${var.gitea_username} --gecos "" --disabled-password --home /home/${var.gitea_username}
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
        - mkdir -p /home/${var.gitea_username}/data /home/${var.gitea_username}/custom /home/${var.gitea_username}/log
        - chown -R ${var.gitea_username}:${var.gitea_username} /home/${var.gitea_username}
        - chmod -R 755 /home/${var.gitea_username}
        - curl -fsSL https://dl.gitea.com/gitea/1.27.0/gitea-1.27.0-linux-amd64 -o /usr/local/bin/gitea
        - chmod +x /usr/local/bin/gitea
        - |
          cat > /etc/systemd/system/gitea.service <<SERVICE
          [Unit]
          Description=Gitea
          After=network.target
          [Service]
          Type=simple
          User=${var.gitea_username}
          WorkingDirectory=/home/${var.gitea_username}
          ExecStart=/usr/local/bin/gitea web --config /home/${var.gitea_username}/custom/app.ini
          Restart=on-failure
          RestartSec=5
          Environment=HOME=/home/${var.gitea_username} USER=gitea GITEA_WORK_DIR=/home/${var.gitea_username}
          [Install]
          WantedBy=multi-user.target
          SERVICE
        - systemctl daemon-reload
        - restorecon -v /usr/local/bin/gitea
        - systemctl enable gitea
        - systemctl start gitea
        - echo "==> Gitea ready at http://${var.gitea_ip}:3000"
    EOT
  }
}