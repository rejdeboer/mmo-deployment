resource "proxmox_virtual_environment_vm" "k3s_master_01" {
  name        = "k3s-master-01"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "host2"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 12288
  }

  agent {
    enabled = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:BA:5B:D2"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 60
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.kubernetes_ip}/24"
        gateway = local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.k3s_cloud_config.id
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "while [ ! -f /tmp/cloud-config.done ]; do sleep 5; done",
      "echo 'Cloud-init finished!'",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_addresses[1][0]
    }
  }
}

resource "proxmox_virtual_environment_file" "k3s_cloud_config" {
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
      - curl -sfL https://get.k3s.io INSTALL_K3S_EXEC="server --cluster-init --disable=servicelb" | sh -s - server --bind-address 192.168.1.50
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "k3s-cloud-config.yaml"
  }
}

resource "null_resource" "flux_bootstrap" {
  depends_on = [
    proxmox_virtual_environment_vm.k3s_master_01,
  ]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.k3s_master_01.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      ubuntu@${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]} \
      "sudo cat /etc/rancher/k3s/k3s.yaml" | \
      sed 's/127.0.0.1/${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]}/' \
      > ~/.kube/config
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create namespace sealed-secrets
      kubectl apply -f ${var.master_key_manifest_path}

      flux bootstrap github \
      --components-extra=image-reflector-controller,image-automation-controller \
      --owner=rejdeboer \
      --repository=mmo-deployment \
      --branch=main \
      --path=./clusters/staging \
      --read-write-key \
      --personal
    EOT

    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
}

