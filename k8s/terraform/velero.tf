
resource "kubernetes_namespace" "velero" {
  metadata {
    name = "velero"
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

resource "kubernetes_secret" "velero-aws-credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }
  data = {
    cloud = <<EOF
[default]
aws_access_key_id=${aws_iam_access_key.cluster_buckets_user.id}
aws_secret_access_key=${aws_iam_access_key.cluster_buckets_user.secret}
EOF
  }
}

# s3 bucket for storage
resource "aws_s3_bucket" "cluster_backups" {
  bucket_prefix = "cluster-backups"
  acl           = "private"
  force_destroy = false
}

# IAM USER to access this bucket
resource "aws_iam_user" "cluster_buckets_user" {
  name          = "cluster-backups-user"
  force_destroy = true
}

# keys for this user
resource "aws_iam_access_key" "cluster_buckets_user" {
  user = aws_iam_user.cluster_buckets_user.name
}

# aws user to access the bucket
data "aws_iam_policy_document" "cluster_buckets_policy" {
  statement {
    actions = [
      "s3:PutObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:Abort*",
      "s3:GetObject*"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.cluster_backups.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.cluster_backups.bucket}/*"
    ]
  }
}

# policy to access the s3 bucket
resource "aws_iam_policy" "cluster_buckets_policy" {
  name_prefix = "cluster-bucket-backup-access-"
  policy      = data.aws_iam_policy_document.cluster_buckets_policy.json
}

# attach policy to user
resource "aws_iam_user_policy_attachment" "cluster_buckets_policy_attachment" {
  user       = aws_iam_user.cluster_buckets_user.name
  policy_arn = aws_iam_policy.cluster_buckets_policy.arn
}
