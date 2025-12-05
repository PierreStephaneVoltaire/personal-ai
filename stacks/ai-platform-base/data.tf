data "terraform_remote_state" "rancher_cluster" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "nolift/stacks/rancher-cluster/terraform.tfstate"
    region = "ca-central-1"
  }
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "nolift/infra/terraform.tfstate"
    region = "ca-central-1"
  }
}
