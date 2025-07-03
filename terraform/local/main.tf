terraform {
  backend "azurerm" {
    resource_group_name  = "storage-account-resource-group"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/homelab.tfstate"
    // MSDN development subscription is used for infra
    subscription_id = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.2"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "proxmox" {
  endpoint = "https://192.168.0.112:8006/api2/json"
  insecure = true
}
