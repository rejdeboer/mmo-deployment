provider "minio" {
  minio_server   = var.minio_address
  minio_user     = var.minio_root_user
  minio_password = var.minio_root_password
}
