# Flux Bootstrap
# NOTE: If migrating from the old fluxcd/flux 0.x provider, remove the old
# state entries before applying:
#   terraform state rm github_repository_file.install
#   terraform state rm github_repository_file.sync
#   terraform state rm github_repository_file.kustomize
# Then import the existing installation:
#   terraform import flux_bootstrap_git.main flux-system

resource "flux_bootstrap_git" "main" {
  depends_on = [github_repository_deploy_key.main, kubernetes_secret.main]

  version                 = "v2.7.5"
  path                    = var.target_path
  network_policy          = false
  interval                = "10m0s"
  disable_secret_creation = true
}

# Kubernetes
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations
    ]
  }
}

resource "kubernetes_secret" "main" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

# GitHub

data "github_repository" "main" {
  name = var.repository_name
}

resource "github_repository_deploy_key" "main" {
  title      = "staging-cluster"
  repository = data.github_repository.main.name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}

resource "kubernetes_secret" "sops-gpg" {
  metadata {
    name      = "sops-gpg"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
    labels = {
      "gnerated-by" = "terraform"
    }
  }
  data = {
    "sops.asc" = file(var.gpg_privae_key_file)
  }

}


# injected config
resource "kubernetes_config_map" "cluster-settings" {
  metadata {
    name      = "cluster-settings"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
    labels = {
      "gnerated-by" = "terraform"
    }
  }
  data = {
    METALLB_LB_RANGE     = var.metal_lb_range
    BASE_DOMAIN          = var.base_domain
    VELERO_SECRET_NAME   = kubernetes_secret.velero-aws-credentials.metadata[0].name
    VELERO_BACKUP_BUCKET = aws_s3_bucket.cluster_backups.bucket
    VELERO_SECRET_NAME_B2   = kubernetes_secret.velero-b2-credentials.metadata[0].name
    VELERO_BACKUP_BUCKET_B2 = b2_bucket.cluster_backups.bucket_name
    VELERO_BACKUP_B2_URL = data.b2_account_info.backup-info.s3_api_url
    VELERO_BACKUP_B2_REGION = regex("s3\\.(.*)\\.backblazeb2\\.com", data.b2_account_info.backup-info.s3_api_url)[0]
    AWS_REGION           = local.aws_region
    SMTP_HOST            = local.smtp_host
    SMTP_USER            = local.smtp_user
    EXTERNAL_DOMAIN      = var.external_domain
    DKIM_KEY_NAME        = local.dkim_key_name
  }
}

resource "kubernetes_secret" "cluster-secrets" {
  metadata {
    name      = "cluster-secrets"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
    labels = {
      "gnerated-by" = "terraform"
    }
  }
  data = {
    SMTP_PASS        = local.smtp_pass
    # DKIM_PRIVATE_KEY = local.dkim_private_key
  }

}
