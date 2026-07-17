output "vm_summary" {
  value = {
    pfsense = {
      vmid = proxmox_virtual_environment_vm.pfsense.vm_id
      ip   = "192.168.1.151"
      note = "Set IP manually during pfSense console install"
    }
    gitea = {
      vmid = proxmox_virtual_environment_vm.gitea.vm_id
      ip   = "192.168.1.152"
      url  = "http://192.168.1.152:3000"
      note = "Finish first-run setup via web UI"
    }
    k3s = {
      vmid         = proxmox_virtual_environment_vm.k3s_master.vm_id
      ip           = "192.168.1.153"
      # kubeconfig   = "scp ubuntu@192.168.1.153:~/.kube/config ~/.kube/config-homelab"
    }
    registry = {
      vmid = proxmox_virtual_environment_vm.registry.vm_id
      ip   = "192.168.1.154"
      url  = "http://192.168.1.154:5000"
    }
    jenkins = {
      vmid = proxmox_virtual_environment_vm.jenkins.vm_id
      ip   = "192.168.1.155"
      url  = "http://192.168.1.155:5000"
    }
    # vpn = {
    #   vmid = proxmox_virtual_environment_vm.vpn.vm_id
    #   ip   = "192.168.1.155"
    #   note = <<-EON
    #     Post-deploy steps:
    #       1. sudo zerotier-cli join <network-id>
    #       2. Approve VM at https://my.zerotier.com
    #       3. sudo zerotier-cli listnetworks  (note ZeroTier IP)
    #       4. Edit /etc/openvpn/server.conf — uncomment 'local', set ZeroTier IP
    #       5. sudo systemctl restart openvpn@server
    #       6. sudo bash /opt/openvpn-client-gen.sh <device-name>
    #   EON
    # }
  }
}

# output "k3s_worker_join_command" {
#   value = <<-EOC
#     # 1. Get node token:
#     ssh ubuntu@192.168.1.153 "cat /var/lib/rancher/k3s/server/node-token"

#     # 2. On worker machine:
#     curl -sfL https://get.k3s.io | \
#       K3S_TOKEN=<paste_token> \
#       K3S_URL=https://192.168.1.153:6443 \
#       INSTALL_K3S_EXEC="agent --node-label role=worker" sh -

#     # Or use: bash k3s_worker_join.sh <worker-hostname>
#   EOC
# }
