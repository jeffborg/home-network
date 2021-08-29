

resource "random_password" "webhook-token" {
  length = 40
  special = true
}

resource "github_repository_webhook" "main" {
    count = var.webhok_target_url != null ? 1 : 0
    repository = data.github_repository.main.name
    events = [ "push" ] 
    configuration {
      url = "${var.webhook_external_base_url}${var.webhok_target_url}"
      secret = random_password.webhook-token.result
      content_type = "form"
    }
}

# push secret into k8s
resource "kubernetes_secret" "webhook-token" {
  metadata {
    name = "webhook-token"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
  data = {
    "token" = random_password.webhook-token.result
  }
}

