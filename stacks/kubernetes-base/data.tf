data "terraform_remote_state" "rancher_cluster" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/stacks/rancher-cluster/terraform.tfstate"
    region = "ca-central-1"
  }
}

locals {
  cluster_name = "${var.project_name}-${var.environment}"
}
