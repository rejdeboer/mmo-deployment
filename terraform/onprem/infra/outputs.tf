output "kubeconfig_command" {
  description = "Run this command to get kubeconfig file. Should spit out something like: ssh -o StrictHostKeyChecking=no ubuntu@192.168.1.50 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/192.168.1.50/' > ~/.kube/config"
  value       = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]}/' > ~/.kube/config"
}

output "kubernetes_ip" {
  description = "IP address of the Kubernetes control plane"
  value       = proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]
}

output "minio_ip" {
  description = "IP address of Minio"
  value       = proxmox_virtual_environment_vm.minio.ipv4_addresses[1][0]
}

output "vault_ip" {
  description = "IP address of Hashicorp Vault deployment"
  value       = proxmox_virtual_environment_vm.vault.ipv4_addresses[1][0]
}
