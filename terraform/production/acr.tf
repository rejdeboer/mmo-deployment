resource "azurerm_container_registry" "acr" {
  name                = "rejdeboer"
  sku                 = "Basic"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  network_rule_set    = []
}

resource "azurerm_role_assignment" "cluster_allow_acr" {
  principal_id                     = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
