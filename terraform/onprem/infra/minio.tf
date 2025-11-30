resource "proxmox_virtual_environment_vm" "minio" {
  name        = "minio"
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
    mac_address = "BC:24:11:BA:5B:D5"
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
    size         = 200
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.minio_ip}/24"
        gateway = local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.minio_cloud_config.id
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

resource "proxmox_virtual_environment_file" "minio_cloud_config" {
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
        password: ${var.minio_root_password}
        groups:
          - sudo
          - docker
        shell: /bin/bash
        ssh_authorized_keys:
%{for key in var.ssh_public_keys~}
          - ${key}
%{endfor~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
      - ca-certificates
      - curl
      - gnupg

    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent

      - install -m 0755 -d /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      - chmod a+r /etc/apt/keyrings/docker.gpg
      - echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable' > /etc/apt/sources.list.d/docker.list
      - apt-get update
      - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

      - mkfs.ext4 /dev/vdb
      - mkdir -p /mnt/minio_data
      - mount /dev/vdb /mnt/minio_data
      # Add to /etc/fstab to make the mount persistent across reboots
      - echo '/dev/vdb /mnt/minio_data ext4 defaults 0 0' >> /etc/fstab
      # Set correct ownership for the mounted volume
      - chown -R debian:debian /mnt/minio_data

      - |
        cat <<'DOCKER_COMPOSE_EOF' > /home/debian/docker-compose.yml
        version: '3.8'

        services:
          minio:
            image: minio/minio:RELEASE.2025-09-07T16-13-09Z
            ports:
              - "${local.minio_console_port}:${local.minio_console_port}"
              - "9000:9000"
            volumes:
              - /mnt/minio_data:/data
            environment:
              # IMPORTANT: Terraform variables are expanded here.
              - MINIO_ROOT_USER=${var.minio_root_user}
              - MINIO_ROOT_PASSWORD=${var.minio_root_password}
            command: server /data --console-address ":${local.minio_console_port}"
            restart: unless-stopped
        DOCKER_COMPOSE_EOF

      - chown debian:debian /home/debian/docker-compose.yml
      - cd /home/debian && docker compose up -d

      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "minio-cloud-config.yaml"
  }
}

