provider "github" {
  owner = local.github_org
  token = var.github_token
}

data "github_actions_registration_token" "server_runner" {
  repository = local.github_server_repository
}

resource "proxmox_virtual_environment_vm" "github_runner" {
  name        = "github-runner"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "host2"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
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
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = 50
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.github_runner_ip}/24"
        gateway = local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.github_runner_cloud_config.id
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

resource "proxmox_virtual_environment_file" "github_runner_cloud_config" {
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
        shell: /bin/bash
        ssh_authorized_keys:
%{for key in var.ssh_public_keys~}
          - ${key}
%{endfor~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
      - gnupg

    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent

      - cd home/debian
      - chown -R debian:debian /home/debian/actions-runner
      - sudo apt update && sudo apt install perl libicu-dev -y
      - mkdir actions-runner && cd actions-runner
      - curl -o actions-runner-linux-x64-2.335.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz
      - echo "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf  actions-runner-linux-x64-2.335.1.tar.gz" | shasum -a 256 -c
      - tar xzf ./actions-runner-linux-x64-2.335.1.tar.gz
      - su - debian -c './config.sh --url https://github.com/${local.github_org}/${local.github_server_repository} --token ${data.github_actions_registration_token.server_runner.token} --unattended --work _work --labels "self-hosted,Linux,X64" --name homelab'
      - sudo ./svc.sh install debian
      - sudo ./svc.sh start


      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "github-runner-cloud-config.yaml"
  }
}

