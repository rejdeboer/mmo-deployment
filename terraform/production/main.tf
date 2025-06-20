terraform {
  backend "azurerm" {
    resource_group_name  = "storage-account-resource-group"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "infrastructure.tfstate"
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
    vercel = {
      source  = "vercel/vercel"
      version = "1.10.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.34.0"
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
  project_name = "multiplayer-server"
  organization = "rejdeboer"
  environment  = "prd"
}
