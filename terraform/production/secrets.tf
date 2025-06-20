resource "random_string" "postgres_username" {
  length  = 16
  special = false
  numeric = false
}

resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "random_password" "jwt_secret_key" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "postgres_username" {
  name         = "postgres-username"
  value        = random_string.postgres_username.result
  key_vault_id = azurerm_key_vault.akv.id
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = random_password.postgres_password.result
  key_vault_id = azurerm_key_vault.akv.id
}

resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "jwt-secret-key"
  value        = random_password.jwt_secret_key.result
  key_vault_id = azurerm_key_vault.akv.id
}

resource "azurerm_key_vault_secret" "cloudflare_api_token" {
  name         = "cloudflare-api-token"
  value        = var.cloudflare_api_token
  key_vault_id = azurerm_key_vault.akv.id
}
