resource "proxmox_virtual_environment_vm" "garage" {
  name        = "garage"
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
    mac_address = "BC:24:11:BA:5B:D6"
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

  serial_device {
    device = "socket"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.garage_ip}/24"
        gateway = local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.garage_cloud_config.id
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

resource "proxmox_virtual_environment_file" "garage_cloud_config" {
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
        shell: /bin/bash
        ssh_authorized_keys:
%{for key in var.ssh_public_keys~}
          - ${key}
%{endfor~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
      - wget

    write_files:
      - path: /etc/garage/garage.toml
        content: |
          metadata_dir = "/mnt/data/meta"
          data_dir = "/mnt/data/data"
          db_engine = "sqlite"

          replication_factor = 1

          rpc_bind_addr = "[::]:3901"
          rpc_public_addr = "127.0.0.1:3901"
          rpc_secret = "${random_bytes.garage_rpc_secret.hex}"

          [s3_api]
          s3_region = "eu-central-1"
          api_bind_addr = "[::]:3901"
          root_domain = ".s3.rejdeboer.com"

          [s3_web]
          bind_addr = "[::]:3900"
          root_domain = ".web.rejdeboer.com"

          [admin]
          api_bind_addr = "[::]:3903"
          admin_token = "${random_bytes.garage_admin_token.base64}"
          metrics_token = "${random_bytes.garage_metrics_token.base64}"

      - path: /etc/systemd/system/garage.service
        content: |
          [Unit]
          Description=Garage Object Storage
          After=network.target

          [Service]
          ExecStart=/usr/local/bin/garage server
          Restart=always
          User=root

          [Install]
          WantedBy=multi-user.target

    runcmd:
      - systemctl enable --now qemu-guest-agent

      - mkdir -p /mnt/data
      - |
        if ! blkid /dev/vdb; then
          mkfs.ext4 /dev/vdb
        fi
      - mount /dev/vdb /mnt/data
      - echo "/dev/vdb /mnt/data ext4 defaults 0 2" >> /etc/fstab

      - wget https://garagehq.deuxfleurs.fr/_releases/v1.0.0/x86_64-unknown-linux-musl/garage -O /usr/local/bin/garage
      - chmod +x /usr/local/bin/garage

      - systemctl enable --now garage
    EOF

    file_name = "garage-cloud-config.yaml"
  }
}

resource "random_bytes" "garage_rpc_secret" {
  length = 32
}

resource "random_bytes" "garage_admin_token" {
  length = 32
}

resource "random_bytes" "garage_metrics_token" {
  length = 32
}
