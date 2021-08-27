# resource "helm_release" "rancher" {
#   repository       = "https://releases.rancher.com/server-charts/stable"
#   namespace        = "cattle-system"
#   create_namespace = true
#   name             = "rancher"
#   chart            = "rancher"
#   version          = "2.5.9"
#   timeout          = 600
#   set {
#     name  = "hostname"
#     value = "rancher.192.168.58.135.sslip.io"
#   }
#   set {
#     name  = "ingress.tls.source"
#     value = "secret"
#   }
#   set {
#     name  = "replicas"
#     value = 1
#   }
# }
