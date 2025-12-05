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


data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
    count             =  length(data.kubectl_file_documents.gateway_api_crds.documents)

  yaml_body         = element(data.kubectl_file_documents.gateway_api_crds.documents, count.index)
  server_side_apply = true
  force_conflicts = true
}

resource "helm_release" "nginx_gateway_fabric" {
  name             = "nginx-gateway-fabric"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  namespace        = "nginx-gateway"
  create_namespace = true
  version          = "1.4.0"

  values = [
    yamlencode({
      nginxGateway = {
        config = {
          logging = {
            level = "debug"
          }
        }
      }
      nginx = {
        config = {
          entries = [
            { name = "proxy_intercept_errors", value = "off" },
            { name = "proxy_connect_timeout", value = "60s" },
            { name = "proxy_send_timeout", value = "60s" },
            { name = "proxy_read_timeout", value = "60s" },
            { name = "client_max_body_size", value = "100m" }
          ]
        }
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]

  depends_on = [kubectl_manifest.gateway_api_crds]
}

resource "kubectl_manifest" "nginx_gateway" {

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-gateway"
      namespace = "nginx-gateway"
      annotations = {
        "cert-manager.io/cluster-issuer" = "zerossl-prod"
      }
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

  depends_on = [helm_release.nginx_gateway_fabric]
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
            http01 = {
              gatewayHTTPRoute = {
                parentRefs = [
                  {
                    name        = "nginx-gateway"
                    namespace   = "nginx-gateway"
                    kind        = "Gateway"
                    sectionName = "http"
                  }
                ]
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager, helm_release.nginx_gateway_fabric, kubernetes_secret.zerossl_eab]
}

resource "kubectl_manifest" "cert_reference_grant" {
  count = var.stopped ? 0 : 1

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

  depends_on = [helm_release.nginx_gateway_fabric]
}

data "kubernetes_service" "nginx_gateway" {
  metadata {
    name      = "nginx-gateway-fabric"
    namespace = "nginx-gateway"
  }

  depends_on = [kubectl_manifest.nginx_gateway]
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "cluster_wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [data.kubernetes_service.nginx_gateway[0].status[0].load_balancer[0].ingress[0].ip]
}
