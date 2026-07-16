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
    vm_id = proxmox_virtual_environment_vm.rocky_template.vm_id
    full  = true
  }

  cpu {
    cores = 2
    limit = 50
    units = 50
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
    size         = 80
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.registry_ip}/24"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = var.dns_servers
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

  # add below to config for fallover
  # ssh_pwauth: True
  # chpasswd:
  #   list: |
  #     rocky:password123
  #   expire: False
  source_raw {
    file_name = "registry-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: docker-registry
      chpasswd:
        list: |
          ${var.registry_username}:${var.registry_password}
        expire: False
      users:
        - default
        - name: ${var.registry_username}
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
        - qemu-guest-agent
      runcmd:
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
        - curl -fsSL https://github.com/distribution/distribution/releases/download/v3.1.1/registry_3.1.1_linux_amd64.tar.gz -o /tmp
        - tar -xzf "/tmp/registry_3.1.1_linux_amd64.tar.gz" /usr/local/bin/registry
        - chmod +x /usr/local/bin/registry
        - rm /tmp/registry_3.1.1_linux_amd64.tar.gz
        - adduser ${var.registry_username} --gecos "" --disabled-password --home /home/${var.registry_username}
        - mkdir -p /home/${var.registry_username}/data
        - |
          cat > /home/${var.registry_username}/config.yml <<CFG
          version: 0.1
          log:
            level: info
          storage:
            filesystem:
              rootdirectory: /home/${var.registry_username}/data
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
        - chown -R ${var.registry_username}:${var.registry_username} /home/${var.registry_username}
        - |
          cat > /etc/systemd/system/registry.service <<SERVICE
          [Unit]
          Description=Distribution Container Registry
          After=network.target
          [Service]
          Type=simple
          User=${var.registry_username}
          ExecStart=/usr/local/bin/registry serve /home/${var.registry_username}/config.yml
          Restart=on-failure
          RestartSec=5
          [Install]
          WantedBy=multi-user.target
          SERVICE
        - systemctl daemon-reload
        - systemctl enable --now registry
        - echo "==> Registry ready at http://${var.registry_ip}:5000"
        - echo "done" > /tmp/cloud-config.done
    EOT
  }
}
