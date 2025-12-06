data "terraform_remote_state" "rancher_cluster" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/stacks/rancher-cluster/terraform.tfstate"
    region = "ca-central-1"
  }
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/infra/terraform.tfstate"
    region = "ca-central-1"
  }
}
