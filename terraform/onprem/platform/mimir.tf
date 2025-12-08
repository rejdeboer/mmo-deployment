resource "minio_s3_bucket" "mimir" {
  bucket = "mimir"
  acl    = "private"
}

resource "minio_iam_user" "mimir" {
  name = "mimir"
}

resource "minio_iam_policy" "mimir" {
  name = "mimir"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = "arn:aws:s3:::${minio_s3_bucket.mimir.bucket}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "arn:aws:s3:::${minio_s3_bucket.mimir.bucket}/*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "mimir" {
  user_name   = minio_iam_user.mimir.name
  policy_name = minio_iam_policy.mimir.name
}

resource "vault_kv_secret_v2" "mimir_s3" {
  mount = vault_mount.kv.path
  name  = "infrastructure/mimir-s3"
  data_json = jsonencode({
    access_key = minio_iam_user.mimir.name
    secret_key = minio_iam_user.mimir.secret
    bucket     = minio_s3_bucket.mimir.bucket
    endpoint   = var.minio_address
  })
}

