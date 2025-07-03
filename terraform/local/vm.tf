resource "proxmox_virtual_environment_file" "debian_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "host1"

  source_file {
    path      = "https://cdimage.debian.org/images/cloud/bullseye/20221219-1234/debian-11-genericcloud-amd64-20221219-1234.qcow2"
    file_name = "debian-11-genericcloud-amd64-20221219-1234.img"
    checksum  = "ba0237232247948abf7341a495dec009702809aa7782355a1b35c112e75cee81"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_master_01" {
  name        = "k8s-controlplane-01"
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = "host1"

  cpu {
    cores = 2
  }

  memory {
    dedicated = 6144
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 32
  }

  serial_device {} # The Debian cloud image expects a serial port to be present

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}

