terraform {
  required_version = ">= 0.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.25.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dme = {
      source  = "DNSMadeEasy/dme"
      version = "1.0.6"
    }
    b2 = {
      source = "Backblaze/b2"
      version = "0.8.9"
    }    
  }
  backend "kubernetes" {
    config_path   = "../ansible/playbooks/output/kubectl.conf"
    secret_suffix = "state"
  }
}
provider "b2" {
  application_key = var.B2_APPLICATION_KEY
  application_key_id = var.B2_APPLICATION_KEY_ID
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
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
