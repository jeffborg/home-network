terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.4.1"
    }
  }
}

provider "kubernetes" {
  config_path = "./k8s/anisible/static/kubectl.conf"
}

provider "helm" {
  kubernetes {
    config_path = "./k8s/anisible/static/kubectl.conf"
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = "my-first-namespace"
  }
}

