locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

resource "rancher2_bootstrap" "admin" {
  initial_password = data.terraform_remote_state.base.outputs.rancher_admin_password
  password         = data.terraform_remote_state.base.outputs.rancher_admin_password
  token_update     = true
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

resource "rancher2_cluster_v2" "main" {
  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  rke_config {
    machine_global_config = yamlencode({
      cloud-provider-name = "external"
    })
  }

  depends_on = [rancher2_bootstrap.admin]
}
resource "local_file" "ssm_params" {
  content = jsonencode({
    commands = ["curl --insecure -fL ${data.terraform_remote_state.base.outputs.rancher_server_url}/system-agent-install.sh | sudo sh -s - --server ${data.terraform_remote_state.base.outputs.rancher_server_url} --label cattle.io/os=linux --token ${rancher2_cluster_v2.main.cluster_registration_token[0].token} --etcd --controlplane --worker"]
  })
  filename = "${path.module}/ssm-params.json"
}

resource "null_resource" "register_node" {
  depends_on = [rancher2_cluster_v2.main, local_file.ssm_params]

  triggers = {
    cluster_id = rancher2_cluster_v2.main.id
  }

  provisioner "local-exec" {
    command = "aws ssm send-command --instance-ids ${data.terraform_remote_state.base.outputs.rancher_server_id} --document-name AWS-RunShellScript --parameters file://${replace(local_file.ssm_params.filename, "\\", "/")} --region ${var.aws_region}"
  }
}


data "rancher2_cluster_v2" "main" {
  name       = rancher2_cluster_v2.main.name
}
