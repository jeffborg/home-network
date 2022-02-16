
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
  force_destroy = false
}

resource "aws_s3_bucket_acl" "cluster_backups_acl" {
  bucket = aws_s3_bucket.cluster_backups.id
  acl    = "private"
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
      "s3:GetObject*",
      "s3:Delete*"
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

resource "random_pet" "bucket_name" {
}
# backblaze target

resource "b2_bucket" "cluster_backups" {
  bucket_name = "cluster-backups-${random_pet.bucket_name.id}"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "cluster_backups" {
  capabilities = [
    "deleteFiles", "listAllBucketNames", "listBuckets", "listFiles", "readBucketEncryption",
    "readBuckets", "readFiles", "shareFiles", "writeBucketEncryption", "writeFiles"
  ]
  bucket_id = b2_bucket.cluster_backups.id
  key_name = "cluster-backups-access-${random_pet.bucket_name.id}"
}

resource "kubernetes_secret" "velero-b2-credentials" {
  metadata {
    name      = "b2-credentials"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }
  data = {
    cloud = <<EOF
[default]
aws_access_key_id=${b2_application_key.cluster_backups.application_key_id}
aws_secret_access_key=${b2_application_key.cluster_backups.application_key}
EOF
  }
}

data "b2_account_info" "backup-info" {
  
}
