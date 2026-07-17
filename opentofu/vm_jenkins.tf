# ##############################################################################
# vm_jenkins.tf
# Deploying Jenkins using the standalone WAR file & running under OpenJDK 25.
# Memory configured for 2GB (2048MB) with JVM heap limits.
# ##############################################################################

resource "proxmox_virtual_environment_vm" "jenkins" {
  name        = "jenkins"
  description = "Jenkins Automation Server — ${var.jenkins_ip}"
  node_name   = var.proxmox_node
  vm_id       = var.vmid_base + 4
  on_boot     = true
  started     = true

  clone {
    vm_id = var.rocky_template_vmid
    full  = true
  }

  cpu {
    cores = 3
    type  = "host"
  }

  memory {
    dedicated = 2048
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
        address = "${var.jenkins_ip}/24"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_data_file_id = proxmox_virtual_environment_file.jenkins_userdata.id
  }

  operating_system { type = "l26" }
  agent            { enabled = true }
}

resource "proxmox_virtual_environment_file" "jenkins_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "jenkins-userdata.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: jenkins-server
      chpasswd:
        list: |
          ${var.jenkins_username}:${var.jenkins_password}
        expire: False
      users:
        - default
        - name: ${var.jenkins_username}
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
        - podman
        - wget
        - qemu-guest-agent
        - fontconfig
        - freetype

      runcmd:
        # 1. Correctly add the Jenkins system user
        - adduser ${var.jenkins_username} --gecos "" --disabled-password --home /home/${var.jenkins_username}

        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent

        # 2. Download and configure OpenJDK 25 Headless JRE (Reduced footprint)
        - mkdir -p /opt/java
        - curl -sL "https://download.oracle.com/java/25/latest/jdk-25_linux-x64_bin.tar.gz" -o /tmp/jdk25.tar.gz
        - tar -xzf /tmp/jdk25.tar.gz -C /opt/java --strip-components=1
        - rm -f /tmp/jdk25.tar.gz
        - ln -sf /opt/java/bin/java /usr/bin/java

        # 3. Download the specific Jenkins WAR stable binary
        - mkdir -p /opt/jenkins
        - curl -sL "https://get.jenkins.io/war-stable/2.568.1/jenkins.war" -o /opt/jenkins/jenkins.war
        - chown -R ${var.jenkins_username}:${var.jenkins_username} /opt/jenkins /home/${var.jenkins_username}

        # 4. Create Systemd Service for the standalone Jenkins WAR
        - |
          cat > /etc/systemd/system/jenkins.service <<SERVICE
          [Unit]
          Description=Jenkins Standalone Automation Server
          After=network.target

          [Service]
          Type=simple
          User=${var.jenkins_username}
          WorkingDirectory=/home/${var.jenkins_username}
          Environment="JENKINS_HOME=/home/${var.jenkins_username} JAVA_HOME=/opt/java"
          ExecStart=/opt/java/bin/java -Xms1024m -Xmx1536m -jar /opt/jenkins/jenkins.war --httpPort=8080
          Restart=on-failure
          RestartSec=10

          [Install]
          WantedBy=multi-user.target
          SERVICE
        - systemctl daemon-reload
        - restorecon -v /opt/java/bin/java
        - systemctl enable jenkins
        - systemctl start jenkins

        # 5. Install Kubernetes Tools (kubectl & Helm)
        - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        - chmod +x ./kubectl
        - mv ./kubectl /usr/local/bin/kubectl
        - curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

        # 6. Configure Podman to connect to local registry over insecure HTTP
        - |
          cat >> /etc/containers/registries.conf <<EOF
          [[registry]]
          location = "${var.registry_ip}:5000"
          insecure = true
          EOF
    EOT
  }
}