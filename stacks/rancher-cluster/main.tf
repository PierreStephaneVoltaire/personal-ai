locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

resource "rancher2_bootstrap" "admin" {
  initial_password = data.terraform_remote_state.base.outputs.rancher_admin_password
  password         = data.terraform_remote_state.base.outputs.rancher_admin_password
  token_update = true
  
}

resource "rancher2_setting" "agenttlsmode" {
  depends_on = [rancher2_bootstrap.admin]
  name       = "agent-tls-mode"
  value      = "system-store"
}

resource "rancher2_cloud_credential" "aws" {
  name = "${local.cluster_name}-aws-creds"

  amazonec2_credential_config {
    access_key = data.aws_caller_identity.current.account_id
    secret_key = ""
  }

  depends_on = [rancher2_bootstrap.admin]
}

data "rancher2_cluster_v2" "main" {
  name = "local"
  depends_on = [rancher2_bootstrap.admin]

}



