# ---------------------------------------------------------------------
# Helm Releases for Cluster Addons
# ---------------------------------------------------------------------

# 1. Cert-Manager with Gateway API support
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.16.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "config.enableGatewayAPI"
    value = "true"
  }
}

# 2. Rancher
resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  namespace        = "cattle-system"
  create_namespace = true

  set {
    name  = "hostname"
    value = "rancher.${var.domain}"
  }

  set {
    name  = "bootstrapPassword"
    value = data.aws_ssm_parameter.rancher_bootstrap_password.value
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "ingress.enabled"
    value = "false"
  }

  set {
    name  = "nodeSelector.workload-type"
    value = "system"
  }

  depends_on = [helm_release.cert_manager]
}


# 4. Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }
}
