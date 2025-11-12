resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
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

    file_name = "user-data-cloud-config.yaml"
  }
}
