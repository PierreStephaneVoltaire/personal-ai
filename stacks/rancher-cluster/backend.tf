terraform {
  backend "s3" {
    bucket       = "pierre-tf-state"
    key          = "ai-platform/stacks/rancher-cluster/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
