# ── OpenVPN + ZeroTier ────────────────────────────────────────────────────────
# LAN IP: 192.168.1.155
#
# Architecture:
#   Devices → ZeroTier (ztX interface, stable mesh IP) → OpenVPN → homelab
#
# ZeroTier gives this VM a stable address even without a static ISP IP.
# OpenVPN clients connect via the ZeroTier IP instead of your real public IP.
#
# Setup steps after deploy:
#   1. SSH in: ssh ubuntu@192.168.1.155
#   2. Join ZeroTier network: sudo zerotier-cli join <your-network-id>
#   3. Approve the VM in ZeroTier Central (https://my.zerotier.com)
#   4. Get ZeroTier IP: sudo zerotier-cli listnetworks
#   5. OpenVPN wizard runs automatically — certs are in /etc/openvpn/easy-rsa/
#   6. Generate a client: sudo /opt/openvpn-client-gen.sh <client-name>
#      → Downloads to /home/ubuntu/<client-name>.ovpn
#   7. In the .ovpn file, replace ZEROTIER_IP with your actual ZeroTier IP
# ─────────────────────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "vpn" {
  name        = "vpn"
  description = "OpenVPN server + ZeroTier client — 192.168.1.155"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 4   # 204
  on_boot     = true
  started     = true

  clone {
    vm_id = var.ubuntu_template_vmid
    full  = true
  }

  cpu {
    cores = 1
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
    size         = 10
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.155/24"
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
    user_data_file_id = proxmox_virtual_environment_file.vpn_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "vpn_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "vpn-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - openvpn
        - easy-rsa
        - curl
        - iptables-persistent

      runcmd:
        # ── ZeroTier ──────────────────────────────────────────────────────
        - curl -s https://install.zerotier.com | bash
        - systemctl enable --now zerotier-one
        # Join your network manually after deploy:
        #   sudo zerotier-cli join <your-network-id>
        - echo "==> ZeroTier installed. Run: sudo zerotier-cli join ${var.zerotier_network_id}"

        # ── OpenVPN PKI setup via Easy-RSA ────────────────────────────────
        - make-cadir /etc/openvpn/easy-rsa
        - cd /etc/openvpn/easy-rsa
        - |
          cat > /etc/openvpn/easy-rsa/vars <<VARS
          set_var EASYRSA_ALGO     ec
          set_var EASYRSA_CURVE    prime256v1
          set_var EASYRSA_CA_EXPIRE   3650
          set_var EASYRSA_CERT_EXPIRE 825
          set_var EASYRSA_REQ_CN      "HomeLabVPN"
          VARS
        - cd /etc/openvpn/easy-rsa && ./easyrsa init-pki
        - cd /etc/openvpn/easy-rsa && echo "HomeLabCA" | ./easyrsa build-ca nopass
        - cd /etc/openvpn/easy-rsa && ./easyrsa build-server-full server nopass
        - cd /etc/openvpn/easy-rsa && ./easyrsa gen-dh
        - openvpn --genkey secret /etc/openvpn/easy-rsa/pki/ta.key

        # ── OpenVPN server config ─────────────────────────────────────────
        # Listens on the ZeroTier interface (zt+) so it's never exposed on
        # your real public IP. Port 1194 UDP.
        - |
          cat > /etc/openvpn/server.conf <<CFG
          port 1194
          proto udp
          dev tun

          # Bind only to ZeroTier interface — not exposed on real public IP
          # Replace with your ZeroTier IP after joining the network
          # local <ZEROTIER_IP>

          ca   /etc/openvpn/easy-rsa/pki/ca.crt
          cert /etc/openvpn/easy-rsa/pki/issued/server.crt
          key  /etc/openvpn/easy-rsa/pki/private/server.key
          dh   /etc/openvpn/easy-rsa/pki/dh.pem
          tls-auth /etc/openvpn/easy-rsa/pki/ta.key 0

          server 10.8.0.0 255.255.255.0
          push "route 192.168.1.0 255.255.255.0"
          push "dhcp-option DNS 192.168.1.1"

          keepalive 10 120
          cipher AES-256-GCM
          auth SHA256
          tls-version-min 1.2
          user nobody
          group nogroup
          persist-key
          persist-tun
          status /var/log/openvpn-status.log
          verb 3
          CFG

        # ── IP forwarding + NAT ───────────────────────────────────────────
        - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        - sysctl -p
        - iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
        - iptables-save > /etc/iptables/rules.v4

        # ── Start OpenVPN ─────────────────────────────────────────────────
        - systemctl enable --now openvpn@server

        # ── Client cert generator script ──────────────────────────────────
        - |
          cat > /opt/openvpn-client-gen.sh <<'SCRIPT'
          #!/usr/bin/env bash
          # Usage: sudo bash /opt/openvpn-client-gen.sh <client-name>
          set -euo pipefail
          CLIENT="$${1:?Usage: $0 <client-name>}"
          PKI="/etc/openvpn/easy-rsa/pki"
          cd /etc/openvpn/easy-rsa
          ./easyrsa build-client-full "$CLIENT" nopass
          cat > /home/ubuntu/$CLIENT.ovpn <<OVPN
          client
          dev tun
          proto udp
          # Replace ZEROTIER_IP with output of: sudo zerotier-cli listnetworks
          remote ZEROTIER_IP 1194
          resolv-retry infinite
          nobind
          persist-key
          persist-tun
          cipher AES-256-GCM
          auth SHA256
          tls-version-min 1.2
          key-direction 1
          verb 3
          <ca>
          $(cat $PKI/ca.crt)
          </ca>
          <cert>
          $(openssl x509 -in $PKI/issued/$CLIENT.crt)
          </cert>
          <key>
          $(cat $PKI/private/$CLIENT.key)
          </key>
          <tls-auth>
          $(cat $PKI/ta.key)
          </tls-auth>
          OVPN
          chown ubuntu:ubuntu /home/ubuntu/$CLIENT.ovpn
          echo "==> Client config: /home/ubuntu/$CLIENT.ovpn"
          echo "==> Replace ZEROTIER_IP in the file with your ZeroTier IP"
          SCRIPT
        - chmod +x /opt/openvpn-client-gen.sh

        - echo "==> OpenVPN + ZeroTier ready"
        - echo "==> Next steps:"
        - echo "    1. sudo zerotier-cli join <network-id>"
        - echo "    2. Approve VM in https://my.zerotier.com"
        - echo "    3. sudo zerotier-cli listnetworks  (get ZeroTier IP)"
        - echo "    4. Edit /etc/openvpn/server.conf — uncomment 'local' line, set ZeroTier IP"
        - echo "    5. sudo systemctl restart openvpn@server"
        - echo "    6. sudo bash /opt/openvpn-client-gen.sh <your-device-name>"
    EOT
  }
}
