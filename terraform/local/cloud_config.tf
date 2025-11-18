resource "proxmox_virtual_environment_file" "k3s_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "host1"

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: host1
    timezone: Europe/Amsterdam
    users:
      - default
      - name: ubuntu
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
      - curl
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - curl -sfL https://get.k3s.io INSTALL_K3S_EXEC="server --cluster-init --disable=servicelb" | sh -s - server --bind-address 192.168.178.50
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "k3s-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "minio_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "host1"

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: host1
    timezone: Europe/Amsterdam
    users:
      - default
      - name: debian
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
            image: minio/minio:RELEASE.2025-09-07T16-13-09Z-cpuv1
            ports:
              - "9001:9001"
              - "9000:9000"
            volumes:
              - /mnt/minio_data:/data
            environment:
              # IMPORTANT: Terraform variables are expanded here.
              - MINIO_ROOT_USER=${var.minio_user}
              - MINIO_ROOT_PASSWORD=${var.master_password}
            command: server /data --console-address ":9001"
            restart: unless-stopped
        DOCKER_COMPOSE_EOF

      - chown debian:debian /home/debian/docker-compose.yml
      - cd /home/debian && docker compose up -d

      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "minio-cloud-config.yaml"
  }
}
