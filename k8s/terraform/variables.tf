
variable "github_owner" {
  type        = string
  description = "github owner"
}

variable "github_token" {
  type        = string
  description = "github token"
}

variable "repository_name" {
  type        = string
  default     = "test-provider"
  description = "github repository name"
}

variable "branch" {
  type        = string
  default     = "master"
  description = "branch name"
}

variable "target_path" {
  type        = string
  default     = "cluster/base"
  description = "flux sync target path"
}

variable "webhook_external_base_url" {
  type = string
  description = "url to external webhook"
}

variable "webhok_target_url" {
  type = string
  description = "get the target url from flux to setup github hook"
  default = null
}

variable "gpg_privae_key_file" {
  type = string
  description = "path to a file containing the private key for fluxcd (gpg --export-secret-keys --armor ID)"
}

variable "metal_lb_range" {
type = string
description = "range of ip's for metalb"
}
