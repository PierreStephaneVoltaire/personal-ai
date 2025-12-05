terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.7"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
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

provider "helm" {
  kubernetes {
    host  = data.terraform_remote_state.rancher_cluster.outputs.kube_host
    token = data.terraform_remote_state.rancher_cluster.outputs.kube_token

    insecure = true
  }
}

provider "kubectl" {
  host  = data.terraform_remote_state.rancher_cluster.outputs.kube_host
  token = data.terraform_remote_state.rancher_cluster.outputs.kube_token

  load_config_file = false
}
