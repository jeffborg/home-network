terraform {
  required_version = ">= 0.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.13.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.7.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    dme = {
      source  = "DNSMadeEasy/dme"
      version = "1.0.3"
    }
  }
  backend "kubernetes" {
    config_path   = "../ansible/playbooks/output/kubectl.conf"
    secret_suffix = "state"
  }
}

provider "flux" {}

provider "random" {}

# Configure the AWS Provider
provider "aws" {
  region  = local.aws_region
  profile = "personal"
}

locals {
  aws_region = "ap-southeast-2"
}

provider "kubectl" {
  config_path = var.kubeconf_file
}

provider "kubernetes" {
  config_path = var.kubeconf_file
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "dme" {
  api_key    = var.dme_api_key
  secret_key = var.dme_secret_key
}

# SSH
locals {
  known_hosts = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=="
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
