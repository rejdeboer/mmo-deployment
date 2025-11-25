
provider "kubernetes" {
  host = data.azurerm_kubernetes_cluster.this.kube_config[0].host

  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

resource "kubernetes_service_account" "default" {
  metadata {
    name      = "workload-identity-sa"
    namespace = "default"
    annotations = {
    }
  }
}
