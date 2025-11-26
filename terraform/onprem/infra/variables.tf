variable "gateway_ip" {
  type    = string
  default = "192.168.1.1"
}

variable "ssh_public_keys" {
  type = list(string)
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "master_key_manifest_path" {
  type    = string
  default = "~/tmp/sealed-secrets-key.yml"
}

variable "minio_root_user" {
  type    = string
  default = "minio"
}

variable "minio_root_password" {
  type      = string
  sensitive = true
}

variable "vault_ip" {
  description = "Static IP f0r Vault (e.g., 192.168.1.52)"
  default     = "192.168.1.52"
}
