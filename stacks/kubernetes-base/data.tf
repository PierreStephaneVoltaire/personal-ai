data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/infra/terraform.tfstate"
    region = "ca-central-1"
  }
}

data "terraform_remote_state" "rancher_cluster" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/stacks/rancher-cluster/terraform.tfstate"
    region = "ca-central-1"
  }
}

data "aws_route53_zone" "main" {
  name = data.terraform_remote_state.base.outputs.domain_name
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}
