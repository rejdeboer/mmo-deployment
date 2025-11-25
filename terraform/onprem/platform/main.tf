terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/onprem/platform.tfstate"
    subscription_id      = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "1.7.5"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

provider "vault" {
  # Configuration options
}

