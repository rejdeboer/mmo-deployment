terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/infrastructure.tfstate"
    // MSDN development subscription is used for infra
    subscription_id = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
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
