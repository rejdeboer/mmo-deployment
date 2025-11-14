variable "ssh_public_keys" {
  type = list(string)
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "master_key_manifest_path" {
  type    = string
  default = "~/tmp/sealed-secrets-key.yml"
}

variable "minio_user" {
  type    = string
  default = "minio"
}

variable "minio_password" {
  type      = string
  sensitive = true
}
