terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/onprem/apps-config.tfstate"
    subscription_id      = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

locals {
  github_org               = "rejdeboer"
  github_server_repository = "mmo-server"
}

provider "github" {
  owner = local.github_org
  token = ephemeral.vault_kv_secret_v2.github.data["pat"]
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

data "vault_kv_secret_v2" "zot_credentials" {
  mount = var.vault_mount_path
  name  = "infrastructure/zot-credentials"
}

ephemeral "vault_kv_secret_v2" "github" {
  mount = var.vault_mount_path
  name  = "cicd/github"
}

resource "github_actions_secret" "registry_username" {
  repository  = local.github_server_repository
  secret_name = "REGISTRY_USERNAME"
  value       = data.vault_kv_secret_v2.zot_credentials.data["username"]
}

resource "github_actions_secret" "registry_password" {
  repository  = local.github_server_repository
  secret_name = "REGISTRY_PASSWORD"
  value       = data.vault_kv_secret_v2.zot_credentials.data["password"]
}

resource "github_actions_variable" "registry_url" {
  repository    = local.github_server_repository
  variable_name = "REGISTRY_URL"
  value         = "registry.rejdeboer.com"
}
