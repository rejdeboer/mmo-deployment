variable "ssh_public_key" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}
