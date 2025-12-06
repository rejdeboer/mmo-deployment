resource "minio_s3_bucket" "tempo" {
  bucket = "tempo"
  acl    = "private"
}

resource "minio_iam_user" "tempo" {
  name = "tempo"
}

resource "minio_iam_policy" "tempo" {
  name = "tempo"
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
        Resource = "arn:aws:s3:::${minio_s3_bucket.tempo.bucket}"
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
        Resource = "arn:aws:s3:::${minio_s3_bucket.tempo.bucket}/*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "tempo" {
  user_name   = minio_iam_user.tempo.name
  policy_name = minio_iam_policy.tempo.name
}

resource "vault_kv_secret_v2" "tempo_s3" {
  mount = vault_mount.kv.path
  name  = "infrastructure/tempo-s3"
  data_json = jsonencode({
    access_key = minio_iam_user.tempo.name
    secret_key = minio_iam_user.tempo.secret
    bucket     = minio_s3_bucket.tempo.bucket
    endpoint   = var.minio_address
  })
}

