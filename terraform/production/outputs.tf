resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.cluster]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.cluster.kube_config_raw
}

output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.cluster.name
}

output "aks_identity_id" {
  value = azurerm_user_assigned_identity.aks.client_id
}
