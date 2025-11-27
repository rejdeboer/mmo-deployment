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
    github = {
      source  = "integrations/github"
      version = "6.8.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = "3.11.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

locals {
  github_org        = "rejdeboer"
  github_repository = "mmo-deployment"
  github_branch     = "main"

  kubeconfig_path     = "~/.kube/config"
  kubeconfig_raw      = file(local.kubeconfig_path)
  kubeconfig          = yamldecode(local.kubeconfig_raw)
  kube_cluster_config = local.kubeconfig.clusters[0].cluster
}
