output "kubeconfig_command" {
  description = "Run this command to get kubeconfig file. Should spit out something like: ssh -o StrictHostKeyChecking=no ubuntu@192.168.1.50 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/192.168.1.50/' > ~/.kube/config"
  value       = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]}/' > ~/.kube/config"
}

output "kubernetes_ip" {
  description = "IP address of the Kubernetes control plane"
  value       = proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[1][0]
}

output "minio_address" {
  description = "The URL to Minio"
  value       = "${proxmox_virtual_environment_vm.minio.ipv4_addresses[1][0]}:${local.minio_api_port}"
}

output "vault_address" {
  description = "The URL to the Hashicorp Vault"
  value       = "http://${proxmox_virtual_environment_vm.vault.ipv4_addresses[1][0]}:${local.vault_api_port}"
}

output "garage_admin_token" {
  description = "Admin token for Garage"
  sensitive   = true
  value       = random_bytes.garage_admin_token.base64
}
