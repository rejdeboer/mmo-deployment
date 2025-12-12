terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "rejdeboertfstate"
    container_name       = "production"
    key                  = "mmo/homelab.tfstate"
    subscription_id      = "17f3be6b-b54a-446b-b4c4-29a7d7b91afe"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.86.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "proxmox" {
  endpoint = "https://192.168.1.101:8006/api2/json"
  insecure = true
}

locals {
  gateway_ip         = "192.168.1.1"
  kubernetes_ip      = "192.168.1.50"
  minio_ip           = "192.168.1.51"
  garage_ip          = "192.168.1.53"
  minio_api_port     = 9000
  minio_console_port = 9001
  vault_ip           = "192.168.1.52"
  vault_api_port     = 8200
  vault_cluster_port = 8201
}
