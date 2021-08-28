

# TOKEN=$(head -c 12 /dev/urandom | shasum | cut -d ' ' -f1)
# echo $TOKEN

# kubectl -n flux-system create secret generic  \	
# --from-literal=token=$TOKEN

resource "random_password" "webhook-token" {
  length = 40
  special = true
}

# resource "github_repository_webhook" "main" {
#     repository = data.github_repository.main.name

#     configuration {
#       url = "${var.webhook_external_base_url}/"
#     }
# }

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

# yamldecode(kubectl_manifest.sync["kustomize.toolkit.fluxcd.io/v1beta1/kustomization/flux-system/flux-system"].yaml_body_parsed).spec.sourceRef.name
# resource "kubernetes" "name" {
  
# }