
# variable "freenas_root_password" {
#   type        = string
#   description = "Freenas root password"
# }

# variable "freenas_host" {
#   type        = string
#   description = "IP address for freenas"
# }

# resource "helm_release" "democratic-csi" {
#   repository       = "https://democratic-csi.github.io/charts/"
#   namespace        = "democratic-csi"
#   create_namespace = true
#   name             = "democratic-csi"
#   chart            = "democratic-csi"
#   version          = "0.8.3"
#   timeout          = 600 # wait 10 minutes
#   values = [templatefile("freenas-nfs.yaml", {
#     host = var.freenas_host
#   })]
#   set_sensitive {
#     name  = "driver.config.httpConnection.password"
#     value = var.freenas_root_password
#   }
#   set_sensitive {
#     name  = "driver.config.sshConnection.password"
#     value = var.freenas_root_password
#   }
# }
