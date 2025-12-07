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

resource "rancher2_machine_config_v2" "worker" {
  generate_name = "${local.cluster_name}-worker"

  amazonec2_config {
    ami                   = data.terraform_remote_state.base.outputs.ami_id
    region                = var.aws_region
    zone                  = substr(data.terraform_remote_state.base.outputs.availability_zone, -1, 1)
    instance_type         = var.worker_instance_type
    vpc_id                = data.terraform_remote_state.base.outputs.vpc_id
    subnet_id             = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
    security_group        = [data.terraform_remote_state.base.outputs.rancher_node_sg_name]
    iam_instance_profile  = data.terraform_remote_state.base.outputs.rancher_node_instance_profile
    root_size             = "50"
    volume_type           = "gp3"
    request_spot_instance = true
    spot_price            = "0.10"
    ssh_user              = "ec2-user"
    tags                  = "kubernetes.io/cluster/${local.cluster_name},owned"
    userdata              = base64encode(<<-EOF
#!/bin/bash
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
EOF
    )
  }
}














resource "rancher2_cluster_v2" "main" {
  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  rke_config {
    machine_global_config = yamlencode({
      cloud-provider-name           = "aws"
      etcd-s3                       = true
      etcd-s3-bucket                = data.terraform_remote_state.base.outputs.s3_bucket
      etcd-s3-region                = var.aws_region
      etcd-s3-folder                = "etcd-snapshots"
      etcd-snapshot-schedule-cron   = "0 */6 * * *"
      etcd-snapshot-retention       = 10
      cni= "canal"
      disable=["traefik"]
    })

    machine_selector_config {
      config = yamlencode({
        disable-cloud-controller    = true
        kube-apiserver-arg          = ["cloud-provider=external"]
        kube-controller-manager-arg = ["cloud-provider=external"]
        kubelet-arg                 = ["cloud-provider=external"]
      })
    }

    machine_pools {
      name                         = "pool1"
      cloud_credential_secret_name = rancher2_cloud_credential.aws.id
      control_plane_role           = true
      etcd_role                    = true
      worker_role                  = true
      quantity                     = 1
      max_unhealthy                = "100%"

      machine_config {
        kind = rancher2_machine_config_v2.worker.kind
        name = rancher2_machine_config_v2.worker.name
      }
        rolling_update {
        max_unavailable = "1"
        max_surge       = "1"
      }
    }
  }

  depends_on = [rancher2_bootstrap.admin]
}

data "rancher2_cluster_v2" "main" {
  name       = rancher2_cluster_v2.main.name
  depends_on = [rancher2_cluster_v2.main]
}
