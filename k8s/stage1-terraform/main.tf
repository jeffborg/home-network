terraform {

  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "remote" {
    organization = "jeffborg"

    workspaces {
      name = "home-network"
    }
  }
}


provider "aws" {
  region = local.aws_region
  profile = "personal"
}

locals {
  aws_region = "ap-southeast-2"
}
