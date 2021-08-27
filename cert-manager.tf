# resource "kubernetes_namespace" "cert-manager" {
#   metadata {
#     name = "cert-manager"
#   }
# }

# resource "helm_release" "cert-manager" {
#   repository = "https://charts.jetstack.io"
#   chart      = "cert-manager"
#   version    = "1.5.3"
#   name       = "cert-manager"
#   namespace  = kubernetes_namespace.cert-manager.metadata[0].name
#   timeout    = 600
#   set {
#     name  = "installCRDs"
#     value = true
#   }
# }


# resource "kubernetes_secret" "ca" {
#   metadata {
#     name      = "ca-key-pair"
#     namespace = kubernetes_namespace.cert-manager.metadata[0].name
#   }
#   data = {
#     "tls.crt" = file("ca.crt")
#     "tls.key" = file("ca.key")
#   }
# }



# resource "kubernetes_manifest" "name" {
# #   count = 0
#   depends_on = [
#     helm_release.cert-manager
#   ]
#   manifest = {
#     apiVersion = "cert-manager.io/v1"
#     kind       = "ClusterIssuer"
#     metadata = {
#       name      = "ca-issuer"
#     }
#     spec = {
#       ca = {
#         secretName = kubernetes_secret.ca.metadata[0].name
#       }
#     }
#   }
# }
