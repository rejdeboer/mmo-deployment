provider "kubernetes" {
  config_path = local.kubeconfig_path
}

# NOTE: Account used by Vault to validate service account secret permissions
resource "kubernetes_service_account" "vault_reviewer" {
  metadata {
    name      = "vault-reviewer"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "vault_reviewer" {
  metadata {
    name = "vault-reviewer-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_reviewer.metadata[0].name
    namespace = kubernetes_service_account.vault_reviewer.metadata[0].namespace
  }
}

resource "kubernetes_secret" "vault_reviewer_token" {
  metadata {
    name      = "vault-reviewer-token"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_reviewer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

