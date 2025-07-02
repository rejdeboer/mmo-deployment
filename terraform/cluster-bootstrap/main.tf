terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    key                  = "mmo/cluster.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.96.0"
    }
    github = {
      source  = "integrations/github"
      version = ">=5.18.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">=1.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

