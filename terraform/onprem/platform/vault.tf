provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = local.kube_cluster_config.server
  kubernetes_ca_cert     = base64decode(local.kube_cluster_config["certificate-authority-data"])
  token_reviewer_jwt     = kubernetes_secret.vault_reviewer_token.data.token
  disable_iss_validation = true
}

resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "Main KV-V2 secret engine"
}

resource "vault_policy" "read_secrets" {
  name = "read-secrets"

  policy = <<EOT
path "secret/data/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  backend   = vault_auth_backend.kubernetes.path
  role_name = "eso-role"

  # NOTE: Service account is created by external secrets operator
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]

  token_ttl      = 3600
  token_policies = [vault_policy.read_secrets.name]
}

resource "random_password" "postgres_root" {
  length  = 24
  special = false
}

resource "vault_kv_secret_v2" "postgres" {
  mount = vault_mount.kv.path
  name  = "infrastructure/postgres"

  data_json = jsonencode({
    username = "mmo"
    password = random_password.postgres_root.result
  })
}

resource "random_bytes" "netcode_private_key" {
  length = 32
}

resource "vault_kv_secret_v2" "netcode_private_key" {
  mount = vault_mount.kv.path
  name  = "app/netcode-private-key"

  data_json = jsonencode({
    private-key = random_bytes.netcode_private_key.base64
  })
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "jwt" {
  mount = vault_mount.kv.path
  name  = "app/jwt"

  data_json = jsonencode({
    secret = random_password.jwt_secret.result
  })
}

resource "vault_kv_secret_v2" "cloudflare" {
  mount = vault_mount.kv.path
  name  = "api/cloudflare-token"

  data_json = jsonencode({
    token = var.cloudflare_token
  })
}

