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
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "256Mi"
        }
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
      domainFilters = [var.domain_name]
      policy        = "sync"
      registry      = "txt"
      txtOwnerId    = local.cluster_name
      interval      = "1m"
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      serviceAccount = {
        create      = true
        annotations = {}
      }
    })
  ]

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    annotations = {
      name = "nginx-gateway"
    }
    name = "nginx-gateway"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    annotations = {
      name = "app"
    }
    name = "app"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  count      = length(data.kubectl_file_documents.gateway_api_crds.documents)
  depends_on = [kubernetes_namespace.nginx]

  yaml_body         = element(data.kubectl_file_documents.gateway_api_crds.documents, count.index)
  server_side_apply = true
  force_conflicts   = true
}

data "http" "nginx_crds" {
  url = "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.2.1/deploy/crds.yaml"
}

data "kubectl_file_documents" "nginx_crds" {
  content = data.http.nginx_crds.response_body
}

resource "kubectl_manifest" "nginx_crds" {
  count = length(data.kubectl_file_documents.nginx_crds.documents)

  yaml_body         = element(data.kubectl_file_documents.nginx_crds.documents, count.index)
  server_side_apply = true
  force_conflicts   = true
  depends_on        = [kubernetes_namespace.nginx, kubectl_manifest.gateway_api_crds]
}

data "http" "nginx_deploy" {
  url = "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.2.1/deploy/default/deploy.yaml"
}

data "kubectl_file_documents" "nginx_deploy" {
  content = data.http.nginx_deploy.response_body
}

resource "kubectl_manifest" "nginx_deploy" {
  count = length(data.kubectl_file_documents.nginx_deploy.documents)

  yaml_body         = element(data.kubectl_file_documents.nginx_deploy.documents, count.index)
  server_side_apply = true
  force_conflicts   = true
  depends_on        = [kubernetes_namespace.nginx, kubectl_manifest.gateway_api_crds]
  ignore_fields = [
    "status",
  ]
}

resource "kubectl_manifest" "nginx_gateway_service_patch" {
  depends_on = [kubectl_manifest.nginx_deploy]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "nginx-gateway-nginx"
      namespace = "nginx-gateway"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-name" = "nginx-gateway-nlb"
      }
    }
    spec = {
      type = "LoadBalancer"
    }
  })
}

resource "kubectl_manifest" "nginx_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-gateway"
      namespace = "nginx-gateway"
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        },
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.${var.domain_name}"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind      = "Secret"
                name      = "wildcard-tls"
                namespace = "app"
              }
            ]
          }
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.gateway_api_crds, kubectl_manifest.nginx_deploy]
}

resource "kubernetes_secret" "zerossl_eab" {
  metadata {
    name      = "zerossl-eab"
    namespace = "cert-manager"
  }

  data = {
    secret = var.zerossl_eab_hmac_key
  }

  type = "Opaque"

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "zerossl_prod" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "zerossl-prod"
    }
    spec = {
      acme = {
        server = "https://acme.zerossl.com/v2/DV90"
        email  = "admin@${var.domain_name}"
        externalAccountBinding = {
          keyID = var.zerossl_eab_kid
          keySecretRef = {
            name = kubernetes_secret.zerossl_eab.metadata[0].name
            key  = "secret"
          }
          keyAlgorithm = "HS256"
        }
        privateKeySecretRef = {
          name = "zerossl-prod"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager, kubernetes_secret.zerossl_eab]
}

resource "kubectl_manifest" "wildcard_certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-tls"
      namespace = "app"
    }
    spec = {
      secretName = "wildcard-tls"
      issuerRef = {
        name = "zerossl-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "*.${var.domain_name}",
        var.domain_name
      ]
    }
  })

  depends_on = [kubectl_manifest.zerossl_prod, kubernetes_namespace.app]
}

resource "kubectl_manifest" "cert_reference_grant" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-nginx-gateway-cert"
      namespace = "app"
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          namespace = "nginx-gateway"
        }
      ]
      to = [
        {
          group = ""
          kind  = "Secret"
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.nginx_deploy, kubernetes_namespace.app]
}
