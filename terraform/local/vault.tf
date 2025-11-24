resource "proxmox_virtual_environment_container" "vault" {
  node_name = "host2"

  unprivileged = true
  features {
    nesting = true
  }

  initialization {
    hostname = "vault"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys     = var.ssh_public_keys
      password = var.master_password
    }
  }

  network_interface {
    name = "veth0"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 4
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_2504_lxc_img.id
    type             = "ubuntu"
  }

  mount_point {
    volume = "/mnt/bindmounts/shared"
    path   = "/mnt/shared"
  }

  mount_point {
    volume = "local-lvm"
    size   = "10G"
    path   = "/mnt/volume"
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_2504_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "host2"
  url          = "https://mirrors.servercentral.com/ubuntu-cloud-images/releases/25.04/release/ubuntu-25.04-server-cloudimg-amd64-root.tar.xz"
}

