# ---------------------------------------------------------------------
# NGINX Gateway Fabric + TLS with Let's Encrypt
# ---------------------------------------------------------------------

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = { for doc in split("---", data.http.gateway_api_crds.response_body) :
    try(yamldecode(doc).metadata.name, "") => doc
    if can(yamldecode(doc).metadata.name)
  }

  yaml_body = each.value

  server_side_apply = true
  wait              = true
}

# 2. NGINX Gateway Fabric Helm Release
resource "helm_release" "nginx_gateway_fabric" {
  name             = "ngf"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  namespace        = "nginx-gateway"
  create_namespace = true
  version          = "1.5.0"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  depends_on = [kubectl_manifest.gateway_api_crds]
}

# 3. Let's Encrypt ClusterIssuer for Gateway API
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
        - http01:
            gatewayHTTPRoute:
              parentRefs:
              - name: main-gateway
                namespace: nginx-gateway
                kind: Gateway
  YAML

  depends_on = [helm_release.cert_manager, helm_release.nginx_gateway_fabric]
}

# 4. Main Gateway with TLS listeners
resource "kubectl_manifest" "main_gateway" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: main-gateway
      namespace: nginx-gateway
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
    spec:
      gatewayClassName: nginx
      listeners:
      - name: http
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: All
      - name: https-litellm
        port: 443
        protocol: HTTPS
        hostname: litellm.${var.domain}
        tls:
          mode: Terminate
          certificateRefs:
          - name: litellm-tls
            kind: Secret
        allowedRoutes:
          namespaces:
            from: All
      - name: https-rancher
        port: 443
        protocol: HTTPS
        hostname: rancher.${var.domain}
        tls:
          mode: Terminate
          certificateRefs:
          - name: rancher-tls
            kind: Secret
        allowedRoutes:
          namespaces:
            from: All
      - name: https-chat
        port: 443
        protocol: HTTPS
        hostname: chat.${var.domain}
        tls:
          mode: Terminate
          certificateRefs:
          - name: chat-tls
            kind: Secret
        allowedRoutes:
          namespaces:
            from: All
      - name: https-n8n
        port: 443
        protocol: HTTPS
        hostname: n8n.${var.domain}
        tls:
          mode: Terminate
          certificateRefs:
          - name: n8n-tls
            kind: Secret
        allowedRoutes:
          namespaces:
            from: All
  YAML

  depends_on = [helm_release.nginx_gateway_fabric, kubectl_manifest.letsencrypt_issuer]
}

# 5. HTTPRoute for LiteLLM
resource "kubectl_manifest" "litellm_route" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: litellm-route
      namespace: ${kubernetes_namespace.ai_platform.metadata[0].name}
    spec:
      parentRefs:
      - name: main-gateway
        namespace: nginx-gateway
      hostnames:
      - litellm.${var.domain}
      rules:
      - backendRefs:
        - name: litellm
          port: 4000
  YAML

  depends_on = [kubectl_manifest.main_gateway, kubernetes_service.litellm]
}

# 6. HTTPRoute for Rancher
resource "kubectl_manifest" "rancher_route" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: rancher-route
      namespace: cattle-system
    spec:
      parentRefs:
      - name: main-gateway
        namespace: nginx-gateway
      hostnames:
      - rancher.${var.domain}
      rules:
      - backendRefs:
        - name: rancher
          port: 80
  YAML

  depends_on = [kubectl_manifest.main_gateway, helm_release.rancher]
}

# 7. HTTPRoute for LibreChat
resource "kubectl_manifest" "librechat_route" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: librechat-route
      namespace: ${kubernetes_namespace.ai_platform.metadata[0].name}
    spec:
      parentRefs:
      - name: main-gateway
        namespace: nginx-gateway
      hostnames:
      - chat.${var.domain}
      rules:
      - backendRefs:
        - name: librechat
          port: 3080
  YAML

  depends_on = [kubectl_manifest.main_gateway, kubernetes_service.librechat]
}

# 8. HTTPRoute for n8n
resource "kubectl_manifest" "n8n_route" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: n8n-route
      namespace: ${kubernetes_namespace.ai_platform.metadata[0].name}
    spec:
      parentRefs:
      - name: main-gateway
        namespace: nginx-gateway
      hostnames:
      - n8n.${var.domain}
      rules:
      - backendRefs:
        - name: n8n
          port: 5678
  YAML

  depends_on = [kubectl_manifest.main_gateway, kubernetes_service.n8n]
}
