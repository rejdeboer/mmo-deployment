terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    key                  = "mmo/cluster.tfstate"
    container_name       = "production"
    // MSDN development subscription is used for infra
    subscription_id = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    github = {
      source  = "integrations/github"
      version = ">=6.6.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">=1.6.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

