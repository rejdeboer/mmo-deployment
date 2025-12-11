resource "minio_s3_bucket" "loki" {
  bucket = "loki"
  acl    = "private"
}

resource "minio_iam_user" "loki" {
  name = "loki"
}

resource "minio_iam_policy" "loki" {
  name = "loki"
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
        Resource = "arn:aws:s3:::${minio_s3_bucket.loki.bucket}"
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
        Resource = "arn:aws:s3:::${minio_s3_bucket.loki.bucket}/*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "loki" {
  user_name   = minio_iam_user.loki.name
  policy_name = minio_iam_policy.loki.name
}

resource "vault_kv_secret_v2" "loki_s3" {
  mount = vault_mount.kv.path
  name  = "infrastructure/loki-s3"
  data_json = jsonencode({
    access_key = minio_iam_user.loki.name
    secret_key = minio_iam_user.loki.secret
    bucket     = minio_s3_bucket.loki.bucket
    endpoint   = var.minio_address
  })
}

