terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/infrastructure.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">=1.6.3"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "resource_group" {
  name     = local.project_name
  location = "northeurope"
}

locals {
  project_name = "mmo"
  organization = "rejdeboer"
  environment  = "prd"
}
