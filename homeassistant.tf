# resource "helm_release" "homeassistant" {
#   name       = "home-assistant"
#   repository = "https://k8s-at-home.com/charts/"
#   chart      = "home-assistant"
#   version    = "10.0.0"
#   #   set {
#   #     name = "ingress.main.hosts.0.host"
#   #     value = "*"
#   #   }
#   values = [yamlencode({
#     env = {
#       TZ = "Australia/Sydney"
#     }
#     persistence = {
#       config = {
#         enabled   = true
#         mountPath = "/config"
#       }
#     }
#     ingress = {
#       main = {
#         enabled = true
#         annotations = {
#             "cert-manager.io/cluster-issuer" = "ca-issuer"
#         }
#         tls = [
#             {
#                 hosts = ["homeassistant.192.168.58.135.sslip.io"]
#                 secretName = "homeassistant-tls"
#             }
#         ]
#         hosts = [
#           {
#             host = "homeassistant.192.168.58.135.sslip.io"
#             paths = [
#               {
#                 path = "/"
#               }
#             ]
#           }
#         ]
#       }
#     }
#   })]
# }
