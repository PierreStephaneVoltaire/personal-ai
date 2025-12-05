data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "pierre-tf-state"
    key    = "ai-platform/infra/terraform.tfstate"
    region = "ca-central-1"
  }
}

data "aws_caller_identity" "current" {}
