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

resource "rancher2_machine_config_v2" "controller" {
  generate_name = "${local.cluster_name}-controller"

  amazonec2_config {
    ami                   = data.terraform_remote_state.base.outputs.ami_id
    region                = var.aws_region
    zone                  = substr(data.terraform_remote_state.base.outputs.availability_zone, -1, 1)
    instance_type         = var.control_instance_type
    vpc_id                = data.terraform_remote_state.base.outputs.vpc_id
    subnet_id             = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
    security_group        = [data.terraform_remote_state.base.outputs.rancher_node_sg_name]
    iam_instance_profile  = data.terraform_remote_state.base.outputs.rancher_node_instance_profile
    root_size             = "50"
    volume_type           = "gp3"
      http_endpoint = "enabled"
http_tokens   = "optional"
    request_spot_instance = true
    spot_price            = "0.10"
    ssh_user              = "ec2-user"
    tags                  = "kubernetes.io/cluster/${local.cluster_name},owned"
  }
}

resource "rancher2_setting" "server_url" {
  depends_on = [rancher2_bootstrap.admin]
  name       = "server-url"
  value      = data.terraform_remote_state.base.outputs.rancher_server_url
}

resource "rancher2_cluster_v2" "main" {
  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  rke_config {
    machine_global_config = yamlencode({
      cloud-provider-name         = "aws"
      disable-cloud-controller = true
      etcd-s3                     = true
      etcd-s3-bucket              = data.terraform_remote_state.base.outputs.s3_bucket
      etcd-s3-region              = var.aws_region
      etcd-s3-folder              = "etcd-snapshots"
      etcd-snapshot-schedule-cron = "0 * */6 * *"
      etcd-snapshot-retention     = 10
      disable                     = ["traefik"]
    })
  
  
    

    machine_selector_config {
      config = yamlencode({
        kubelet-arg                 =  [
      "cloud-provider=external"
    ]
      })
      machine_label_selector {
        match_labels = {
          "rke.cattle.io/control-plane-role" = "true"
        }
      }
    }

    machine_selector_config {
      config = yamlencode({
        kubelet-arg =  [
      "cloud-provider=external"
    ]
      })
      machine_label_selector {
        match_labels = {
          "rke.cattle.io/worker-role" = "true"
        }
      }
    }

additional_manifest = <<-EOT
  apiVersion: helm.cattle.io/v1
  kind: HelmChart
  metadata:
    name: aws-cloud-controller-manager
    namespace: kube-system
  spec:
    chart: aws-cloud-controller-manager
    repo: https://kubernetes.github.io/cloud-provider-aws
    targetNamespace: kube-system
    bootstrap: true
    valuesContent: |-
      hostNetworking: true
      nodeSelector:
        node-role.kubernetes.io/control-plane: "true"
      tolerations:
        - key: node.cloudprovider.kubernetes.io/uninitialized
          value: "true"
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
      args:
        - --configure-cloud-routes=false
        - --v=5
        - --cloud-provider=aws
EOT

   machine_pools {
      name               = "control-pool"
      control_plane_role = true
      etcd_role          = true
      worker_role        = false
      quantity           = 1
      max_unhealthy      = "100%"

      machine_config {
        kind = rancher2_machine_config_v2.controller.kind
        name = rancher2_machine_config_v2.controller.name
      }
      rolling_update {
        max_unavailable = "1"
        max_surge       = "1"
      }
    }
  }

  depends_on = [rancher2_bootstrap.admin, rancher2_setting.server_url]
}

data "rancher2_cluster_v2" "main" {
  name       = rancher2_cluster_v2.main.name
  depends_on = [rancher2_cluster_v2.main]
}
