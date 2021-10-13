
# require
# iam user
# s3 bucket

# export var file for ansible

# s3 bucket for storage
resource "aws_s3_bucket" "cluster_snapshot_backups" {
  bucket_prefix = "cluster-snapshots-backups"
  acl           = "private"
  force_destroy = false
}

# IAM USER to access this bucket
resource "aws_iam_user" "cluster_snapshots_buckets_user" {
  name          = "cluster-snapshots-backups-user"
  force_destroy = true
}

# keys for this user
resource "aws_iam_access_key" "cluster_snapshots_buckets_user" {
  user = aws_iam_user.cluster_snapshots_buckets_user.name
}

# aws user to access the bucket
data "aws_iam_policy_document" "cluster_snapshots_buckets_policy" {
  statement {
    actions = [
      "s3:PutObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:Abort*",
      "s3:GetObject*"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.cluster_snapshot_backups.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.cluster_snapshot_backups.bucket}/*"
    ]
  }
}

# policy to access the s3 bucket
resource "aws_iam_policy" "cluster_snapshots_buckets_policy" {
  name_prefix = "cluster-snapshosts-bucket-backup-access-"
  policy      = data.aws_iam_policy_document.cluster_snapshots_buckets_policy.json
}

# attach policy to user
resource "aws_iam_user_policy_attachment" "cluster_snapshots_buckets_policy_attachment" {
  user       = aws_iam_user.cluster_snapshots_buckets_user.name
  policy_arn = aws_iam_policy.cluster_snapshots_buckets_policy.arn
}


resource "local_file" "aws_bucket_paramaters" {
  filename = "../ansible/group_vars/cluster_snapshots.yml"
  content = yamlencode({
    k3s_server = {
        etcd-s3 = true
        etcd-s3-access-key = aws_iam_access_key.cluster_snapshots_buckets_user.id
        etcd-s3-secret-key = aws_iam_access_key.cluster_snapshots_buckets_user.secret
        etcd-s3-bucket = aws_s3_bucket.cluster_snapshot_backups.bucket
        etcd-s3-region = local.aws_region
    }
  })
}
