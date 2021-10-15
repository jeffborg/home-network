

resource "random_password" "webhook-token" {
  length  = 40
  special = true
}

locals {
  webhook_target_sha256 = sha256("${random_password.webhook-token.result}webapp${kubernetes_namespace.flux_system.metadata[0].name}")
  webhook_target_url    = "/hook/${local.webhook_target_sha256}"
}

resource "github_repository_webhook" "main" {
  count      = 1
  repository = data.github_repository.main.name
  events     = ["push"]
  configuration {
    url          = "${var.webhook_external_base_url}${local.webhook_target_url}"
    secret       = random_password.webhook-token.result
    content_type = "form"
  }
}

# push secret into k8s
resource "kubernetes_secret" "webhook-token" {
  metadata {
    name      = "webhook-token"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
  data = {
    "token" = random_password.webhook-token.result
  }
}

