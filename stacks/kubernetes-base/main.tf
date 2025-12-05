locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

resource "kubernetes_namespace" "ai_platform" {
  metadata {
    name = "ai-platform"
    labels = {
      name        = "ai-platform"
      environment = var.environment
    }
  }
}

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}

resource "random_password" "webui_secret_key" {
  length  = 32
  special = false
}

resource "random_password" "mcpo_api_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    LITELLM_MASTER_KEY = random_password.litellm_master_key.result
    OPENROUTER_API_KEY = var.openrouter_api_key
    WEBUI_SECRET_KEY   = random_password.webui_secret_key.result
    MCPO_API_KEY       = random_password.mcpo_api_key.result
    DATABASE_URL       = data.terraform_remote_state.base.outputs.db_connection_string
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "litellm_config" {
  metadata {
    name      = "litellm-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      model_list = [
        for model in var.litellm_models : {
          model_name = model.model_name
          litellm_params = {
            model    = "openrouter/${model.model_id}"
            api_base = "https://openrouter.ai/api/v1"
            api_key  = "os.environ/OPENROUTER_API_KEY"
          }
        }
      ]
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY"
      }
    })
  }
}

resource "kubernetes_config_map" "mcpo_config" {
  metadata {
    name      = "mcpo-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.json" = jsonencode({
      mcpServers = {
        time = {
          command = "uvx"
          args    = ["mcp-server-time", "--local-timezone", var.timezone]
        }
        memory = {
          command = "npx"
          args    = ["-y", "@modelcontextprotocol/server-memory"]
        }
      }
    })
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.14.2"

  values = [
    yamlencode({
      installCRDs = true
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "100m", memory = "256Mi" }
      }
    })
  ]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.3"

  values = [
    yamlencode({
      provider      = "aws"
      domainFilters = [data.terraform_remote_state.base.outputs.domain_name]
      policy        = "sync"
      registry      = "txt"
      txtOwnerId    = local.cluster_name
      interval      = "1m"
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
    })
  ]

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "gateway_api_crds" {
  count             = var.stopped ? 0 : length(data.kubectl_file_documents.gateway_api_crds.documents)
  yaml_body         = element(data.kubectl_file_documents.gateway_api_crds.documents, count.index)
  server_side_apply = true
}

resource "helm_release" "nginx_gateway_fabric" {
  count = var.stopped ? 0 : 1

  name             = "nginx-gateway-fabric"
  repository       = "oci://ghcr.io/nginxinc/charts"
  chart            = "nginx-gateway-fabric"
  namespace        = "nginx-gateway"
  create_namespace = true
  version          = "1.4.0"

  values = [
    yamlencode({
      nginxGateway = {
        gatewayClassName = "nginx"
      }
      nginx = {
        config = {
          entries = [
            { name = "client_max_body_size", value = "100m" }
          ]
        }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
      service = { type = "LoadBalancer" }
    })
  ]

  depends_on = [kubectl_manifest.gateway_api_crds]
}

resource "kubectl_manifest" "nginx_gateway" {
  count = var.stopped ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-gateway"
      namespace = "nginx-gateway"
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      }
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = { namespaces = { from = "All" } }
        },
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode            = "Terminate"
            certificateRefs = [{ kind = "Secret", name = "wildcard-tls", namespace = "ai-platform" }]
          }
          allowedRoutes = { namespaces = { from = "All" } }
        }
      ]
    }
  })

  depends_on = [helm_release.nginx_gateway_fabric]
}

resource "kubectl_manifest" "letsencrypt_prod" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-prod" }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@${data.terraform_remote_state.base.outputs.domain_name}"
        privateKeySecretRef = { name = "letsencrypt-prod" }
        solvers = [{
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [{
                name        = "nginx-gateway"
                namespace   = "nginx-gateway"
                kind        = "Gateway"
                sectionName = "http"
              }]
            }
          }
        }]
      }
    }
  })

  depends_on = [helm_release.cert_manager, helm_release.nginx_gateway_fabric]
}

resource "kubectl_manifest" "cert_reference_grant" {
  count = var.stopped ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-nginx-gateway-cert"
      namespace = "ai-platform"
    }
    spec = {
      from = [{ group = "gateway.networking.k8s.io", kind = "Gateway", namespace = "nginx-gateway" }]
      to   = [{ group = "", kind = "Secret" }]
    }
  })

  depends_on = [helm_release.nginx_gateway_fabric, kubernetes_namespace.ai_platform]
}

data "kubernetes_service" "nginx_gateway" {
  count = var.stopped ? 0 : 1

  metadata {
    name      = "nginx-gateway-fabric"
    namespace = "nginx-gateway"
  }

  depends_on = [helm_release.nginx_gateway_fabric]
}

resource "aws_route53_record" "wildcard" {
  count   = var.stopped ? 0 : 1
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${data.terraform_remote_state.base.outputs.domain_name}"
  type    = "A"
  ttl     = 300
  records = [data.kubernetes_service.nginx_gateway[0].status[0].load_balancer[0].ingress[0].ip]
}

resource "helm_release" "argocd" {
  count = var.stopped ? 0 : 1

  name          = "argocd"
  repository    = "https://argoproj.github.io/argo-helm"
  chart         = "argo-cd"
  version       = "v9.0.5"
  namespace     = "argocd"
  create_namespace = true
  wait          = true
  timeout       = 600

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.kustomize\\.buildOptions"
    value = "--load-restrictor LoadRestrictionsNone"
  }

  set {
    name  = "global.domain"
    value = "argocd.${data.terraform_remote_state.base.outputs.domain_name}"
  }
}

resource "kubectl_manifest" "argocd_httproute" {
  count = var.stopped ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd-route"
      namespace = "argocd"
    }
    spec = {
      parentRefs = [{ name = "nginx-gateway", namespace = "nginx-gateway", sectionName = "https" }]
      hostnames  = ["argocd.${data.terraform_remote_state.base.outputs.domain_name}"]
      rules = [{
        matches     = [{ path = { type = "PathPrefix", value = "/" } }]
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  })

  depends_on = [helm_release.argocd]
}
