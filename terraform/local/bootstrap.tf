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
      --owner=rejdeboer \
      --repository=mmo-deployment \
      --branch=main \
      --path=./clusters/production \
      --personal
    EOT

    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
}
