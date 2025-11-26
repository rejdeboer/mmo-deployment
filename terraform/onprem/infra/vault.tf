resource "proxmox_virtual_environment_vm" "vault" {
  name        = "vault"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "host2"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:BA:5B:D4"
  }

  disk { # OS Disk
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 32
  }

  disk { # Data storage
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = 50
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.vault_ip}/24"
        gateway = local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.vault_cloud_config.id
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "while [ ! -f /tmp/cloud-config.done ]; do sleep 5; done",
      "echo 'Cloud-init finished!'",
    ]

    connection {
      type        = "ssh"
      user        = "debian"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_addresses[1][0]
    }
  }
}

resource "proxmox_virtual_environment_file" "vault_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "host2"

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: host2
    timezone: Europe/Amsterdam
    users:
      - default
      - name: debian
        groups:
          - sudo
          - vault
        shell: /bin/bash
        ssh_authorized_keys:
%{for key in var.ssh_public_keys~}
          - ${key}
%{endfor~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
      - curl
      - gnupg

    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent

      - curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
      - sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
      - sudo apt update
      - sudo apt install vault

      - sudo mkdir -p /opt/vault/data
      - sudo chown -R vault:vault /opt/vault

      - |
        cat <<'VAULT_EOF' > /etc/vault.d/vault.hcl
        ui = true
        disable_mlock = true

        storage "raft" {
          path    = "/opt/vault/data"
          node_id = "node1"
        }

        listener "tcp" {
          address     = "0.0.0.0:${local.vault_api_port}"
          tls_disable = "true"
        }

        api_addr = "http://${local.vault_ip}:${local.vault_api_port}"
        cluster_addr = "http://${local.vault_ip}:${local.vault_cluster_port}"
        VAULT_EOF

      - sudo systemctl enable vault
      - sudo systemctl start vault

      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "vault-cloud-config.yaml"
  }
}

