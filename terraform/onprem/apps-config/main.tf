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
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.1"
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
  harbor_username          = "admin"
}

provider "github" {
  owner = local.github_org
  token = ephemeral.vault_kv_secret_v2.github.data["pat"]
}

provider "harbor" {
  url      = "https://harbor.rejdeboer.com"
  username = local.harbor_username
  password = ephemeral.vault_kv_secret_v2.harbor_credentials.data["admin_password"]
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

ephemeral "vault_kv_secret_v2" "harbor_credentials" {
  mount = var.vault_mount_path
  name  = "infrastructure/harbor-credentials"
}

ephemeral "vault_kv_secret_v2" "github" {
  mount = var.vault_mount_path
  name  = "cicd/github"
}

resource "harbor_project" "game" {
  name   = "game"
  public = false
}

resource "harbor_robot_account" "cicd" {
  name        = "cicd-robot"
  level       = "system"
  description = "Managed by Terraform"

  permissions {
    access {
      action   = "push"
      resource = "repository"
    }
    kind      = "project"
    namespace = "*"
  }

  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = "*"
  }
}

resource "github_actions_secret" "harbor_user" {
  repository  = local.github_server_repository
  secret_name = "HARBOR_USERNAME"
  value       = harbor_robot_account.cicd.full_name
}

resource "github_actions_secret" "harbor_password" {
  repository  = local.github_server_repository
  secret_name = "HARBOR_PASSWORD"
  value       = harbor_robot_account.cicd.secret
}

resource "github_actions_variable" "harbor_project" {
  repository    = local.github_server_repository
  variable_name = "HARBOR_PROJECT"
  value         = harbor_project.game.name
}
