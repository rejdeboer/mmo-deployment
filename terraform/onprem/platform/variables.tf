variable "github_token" {
  type      = string
  sensitive = true
}

variable "minio_address" {
  type = string
}

variable "minio_root_user" {
  type = string
}

variable "minio_root_password" {
  type      = string
  sensitive = true
}

variable "vault_address" {
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}
