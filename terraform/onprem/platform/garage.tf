provider "garage" {
  endpoint = "http://192.168.1.53:3903"
  token    = var.garage_admin_token
}

resource "garage_bucket" "example" {
  global_alias = "my-bucket"
}
