# # this sets up sync for further flux components

# data "flux_sync" "main" {
#   target_path = "clusters/home"
#   url         = "https://github.com/${var.github_owner}/${var.repository_name}"
#   branch      = "flux"
# }

# # Split multi-doc YAML with
# # https://registry.terraform.io/providers/gavinbunney/kubectl/latest
# data "kubectl_file_documents" "sync" {
#   content = data.flux_sync.main.content
# }

# # Convert documents list to include parsed yaml data
# locals {
#   sync = [ for v in data.kubectl_file_documents.sync.documents : {
#       data: yamldecode(v)
#       content: v
#     }
#   ]
# }

# # Apply manifests on the cluster
# resource "kubectl_manifest" "sync" {
#   for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
#   depends_on = [kubernetes_namespace.flux_system]
#   yaml_body = each.value
# }

# # Generate a Kubernetes secret with the Git credentials
# resource "kubernetes_secret" "main" {
#   depends_on = [kubectl_manifest.apply]

#   metadata {
#     name      = data.flux_sync.main.secret
#     namespace = data.flux_sync.main.namespace
#   }

#   data = {
#     username = "git"
#     password = var.flux_token
#   }
# }
