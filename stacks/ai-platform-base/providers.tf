terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host  = data.terraform_remote_state.rancher_cluster.outputs.kube_host
  token = data.terraform_remote_state.rancher_cluster.outputs.kube_token

  insecure = true
}
