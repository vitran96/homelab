resource "proxmox_virtual_environment_vm" "k3s_master" {
  name        = "k3s-master"
  description = "k3s master node — ${var.k3s_master_ip}"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 2   # 202
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
    dedicated = 3584
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
        address = "${var.k3s_master_ip}/24"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_data_file_id = proxmox_virtual_environment_file.k3s_master_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "k3s_master_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "k3s-master-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: k3s-master-node
      chpasswd:
        list: |
          ${var.k3s_master_username}:${var.k3s_master_password}
        expire: False
      users:
        - default
        - name: ${var.k3s_master_username}
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
        - open-iscsi
        - nfs-common
        - qemu-guest-agent
      runcmd:
        - adduser ${var.k3s_master_username} --gecos "" --disabled-password --home /home/${var.k3s_master_username}
        - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644 --tls-san ${var.k3s_master_ip} --node-name k3s-master" sh -
        - mkdir -p /home/${var.k3s_master_username}/.kube
        - cp /etc/rancher/k3s/k3s.yaml /home/${var.k3s_master_username}/.kube/config
        - chown ${var.k3s_master_username}:${var.k3s_master_username} /home/${var.k3s_master_username}/.kube/config
        - sed -i 's/127.0.0.1/${var.k3s_master_ip}/g' /home/${var.k3s_master_username}/.kube/config
        - chmod 640 /var/lib/rancher/k3s/server/node-token
        - chown root:${var.k3s_master_username} /var/lib/rancher/k3s/server/node-token
        - mkdir -p /etc/rancher/k3s
        - |
          cat > /etc/rancher/k3s/registries.yaml <<REG
          mirrors:
            "${var.registry_ip}:5000":
              endpoint:
                - "http://${var.registry_ip}:5000"
          REG
        - systemctl restart k3s
        - until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 5; done
    EOT
  }
}

resource "local_file" "k3s_worker_join" {
  filename        = "${path.module}/k3s_worker_join.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    MASTER_IP="${var.k3s_master_ip}"
    WORKER_NAME="$${1:-$(hostname)}"
    TOKEN=$(ssh -o StrictHostKeyChecking=no ${var.k3s_master_username}@$MASTER_IP "cat /var/lib/rancher/k3s/server/node-token")
    curl -sfL https://get.k3s.io | K3S_TOKEN="$TOKEN" K3S_URL="https://$MASTER_IP:6443" INSTALL_K3S_EXEC="agent --node-name $WORKER_NAME --node-label role=worker" sh -
  EOT
}