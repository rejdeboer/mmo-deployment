variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_identity_id" {
  type = string
}

variable "github_token" {
  sensitive = true
  type      = string
}

variable "github_org" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "github_branch" {
  type = string
}
