# ── k3s Master + Jenkins + OpenClaw + Headlamp ────────────────────────────────
# IP: 192.168.1.153
#
# Pods inside this cluster:
#   Jenkins   → http://192.168.1.153:32000  (NodePort)
#   OpenClaw  → kubectl exec -n openclaw deploy/openclaw -- openclaw onboard
#   Headlamp  → http://192.168.1.153:4466   (NodePort)
#
# Registry is external at 192.168.1.154:5000
# Workers join from external machines — use k3s_worker_join.sh
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "k3s" {
  name        = "k3s-master"
  description = "k3s + Jenkins + OpenClaw + Headlamp — 192.168.1.153"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 2   # 202
  on_boot     = true
  started     = true

  clone {
    vm_id = var.ubuntu_template_vmid
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 3584   # k3s + Jenkins + OpenClaw + Headlamp (~3.5 GB)
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
        address = "192.168.1.153/24"
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
    user_data_file_id = proxmox_virtual_environment_file.k3s_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "k3s_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "k3s-master-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - curl
        - open-iscsi
        - nfs-common

      runcmd:
        # ── k3s ──────────────────────────────────────────────────────────
        - |
          curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
            --disable traefik \
            --disable servicelb \
            --write-kubeconfig-mode 644 \
            --tls-san 192.168.1.153" sh -

        # ── Helm ─────────────────────────────────────────────────────────
        - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

        # ── kubeconfig for ubuntu user ────────────────────────────────────
        - mkdir -p /home/ubuntu/.kube
        - cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
        - chown ubuntu:ubuntu /home/ubuntu/.kube/config
        - sed -i 's/127.0.0.1/192.168.1.153/g' /home/ubuntu/.kube/config

        # ── Node token for worker joins ───────────────────────────────────
        - chmod 640 /var/lib/rancher/k3s/server/node-token
        - chown root:ubuntu /var/lib/rancher/k3s/server/node-token

        # ── Local registry mirror ─────────────────────────────────────────
        - |
          cat > /etc/rancher/k3s/registries.yaml <<REG
          mirrors:
            "192.168.1.154:5000":
              endpoint:
                - "http://192.168.1.154:5000"
          REG

        # ── Wait for node ready ───────────────────────────────────────────
        - until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 5; done

        # ── Jenkins ───────────────────────────────────────────────────────
        - helm repo add jenkins https://charts.jenkins.io
        - helm repo update
        - kubectl create namespace jenkins || true
        - |
          helm upgrade --install jenkins jenkins/jenkins \
            --namespace jenkins \
            --set controller.serviceType=NodePort \
            --set controller.nodePort=32000 \
            --set controller.resources.requests.cpu=200m \
            --set controller.resources.limits.cpu=500m \
            --set controller.resources.requests.memory=256Mi \
            --set controller.resources.limits.memory=512Mi \
            --set persistence.enabled=true \
            --set persistence.size=20Gi \
            --wait --timeout 10m

        # ── Headlamp ─────────────────────────────────────────────────────
        - helm repo add headlamp https://headlamp-k8s.github.io/headlamp/
        - helm repo update
        - |
          helm upgrade --install headlamp headlamp/headlamp \
            --namespace headlamp \
            --create-namespace \
            --set service.type=NodePort \
            --set service.nodePort=4466 \
            --set resources.requests.cpu=50m \
            --set resources.limits.cpu=250m \
            --set resources.requests.memory=64Mi \
            --set resources.limits.memory=128Mi

        # ── OpenClaw ─────────────────────────────────────────────────────
        - curl -fsSL https://get.docker.com | sh
        - |
          cat > /tmp/Dockerfile.openclaw <<DOCKER
          FROM node:22-alpine
          RUN npm install -g openclaw
          RUN adduser -D openclaw
          USER openclaw
          WORKDIR /home/openclaw
          VOLUME ["/home/openclaw/.config"]
          EXPOSE 3000
          CMD ["openclaw", "start"]
          DOCKER
        - docker build -f /tmp/Dockerfile.openclaw -t 192.168.1.154:5000/openclaw:latest .
        - docker push 192.168.1.154:5000/openclaw:latest
        - systemctl disable --now docker
        - kubectl create namespace openclaw || true
        - |
          kubectl apply -n openclaw -f - <<MANIFEST
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: openclaw-config
          spec:
            accessModes: [ReadWriteOnce]
            resources:
              requests:
                storage: 1Gi
          ---
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: openclaw
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: openclaw
            template:
              metadata:
                labels:
                  app: openclaw
              spec:
                containers:
                  - name: openclaw
                    image: 192.168.1.154:5000/openclaw:latest
                    ports:
                      - containerPort: 3000
                    resources:
                      requests:
                        cpu: "100m"
                        memory: "128Mi"
                      limits:
                        cpu: "250m"
                        memory: "256Mi"
                    volumeMounts:
                      - name: config
                        mountPath: /home/openclaw/.config
                volumes:
                  - name: config
                    persistentVolumeClaim:
                      claimName: openclaw-config
          MANIFEST

        - echo "==> k3s ready at 192.168.1.153"
        - echo "==> Jenkins:  http://192.168.1.153:32000"
        - echo "==> Headlamp: http://192.168.1.153:4466"
        - echo "==> OpenClaw onboard: kubectl exec -it -n openclaw deploy/openclaw -- openclaw onboard"
        - echo "==> Worker token: $(cat /var/lib/rancher/k3s/server/node-token)"
    EOT
  }
}

# ── Worker join script ────────────────────────────────────────────────────────
# resource "local_file" "k3s_worker_join" {
#   filename        = "${path.module}/k3s_worker_join.sh"
#   file_permission = "0755"
#   content         = <<-EOT
#     #!/usr/bin/env bash
#     # Usage: bash k3s_worker_join.sh <worker-hostname>
#     set -euo pipefail
#     MASTER_IP="192.168.1.153"
#     WORKER_NAME="${1:-$(hostname)}"
#     echo "==> Fetching node token from master..."
#     TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP \
#       "cat /var/lib/rancher/k3s/server/node-token")
#     echo "==> Joining as $WORKER_NAME..."
#     curl -sfL https://get.k3s.io | \
#       K3S_TOKEN="$TOKEN" \
#       K3S_URL="https://$MASTER_IP:6443" \
#       INSTALL_K3S_EXEC="agent --node-name $WORKER_NAME --node-label role=worker" \
#       sh -
#     echo "==> Done. Verify: kubectl get nodes -o wide"
#   EOT
# }
