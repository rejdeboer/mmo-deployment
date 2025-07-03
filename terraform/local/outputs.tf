output "kubeconfig_command" {
  description = "run this command to get kubeconfig file"
  value       = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[0][0]} \"sudo cat /etc/rancher/k3s/k3s.yaml\" | sed 's/127.0.0.1/${proxmox_virtual_environment_vm.k3s_master_01.ipv4_addresses[0][0]}/' > kubeconfig"
}
