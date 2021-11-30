# Flux
data "flux_install" "main" {
  target_path    = var.target_path
  network_policy = false
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  branch      = var.branch
  interval    = 60 # we are going to configure a webhook
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

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
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

resource "github_repository_file" "install" {
  repository = data.github_repository.main.name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = var.branch
}

resource "github_repository_file" "sync" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = var.branch
}

locals {
  kustomize_file = yamldecode(data.flux_sync.main.kustomize_content)
}
resource "github_repository_file" "kustomize" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.kustomize_path
  content = yamlencode(merge(local.kustomize_file, {
    resources = concat(local.kustomize_file.resources, ["charts"])
  }))
  branch = var.branch
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
