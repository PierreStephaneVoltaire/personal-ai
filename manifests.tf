data "kubectl_file_documents" "tika" {
  content = file("${path.module}/k8s/tika.yaml")
}

resource "kubectl_manifest" "tika" {
  for_each  = data.kubectl_file_documents.tika.manifests
  yaml_body = each.value

  depends_on = [kubernetes_namespace.ai_platform]
}

data "kubectl_file_documents" "valkey" {
  content = file("${path.module}/k8s/valkey.yaml")
}

resource "kubectl_manifest" "valkey" {
  for_each  = data.kubectl_file_documents.valkey.manifests
  yaml_body = each.value

  depends_on = [kubernetes_namespace.ai_platform]
}

data "kubectl_file_documents" "litellm" {
  content = file("${path.module}/k8s/litellm.yaml")
}

resource "kubectl_manifest" "litellm" {
  for_each  = data.kubectl_file_documents.litellm.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    kubernetes_secret.ai_platform_secrets,
    kubernetes_config_map.litellm_config
  ]
}

data "kubectl_file_documents" "council" {
  content = templatefile("${path.module}/k8s/council.yaml", {
    config_hash = sha256(jsonencode(kubernetes_config_map.council_config.data))
  })
}

resource "kubectl_manifest" "council" {
  for_each  = data.kubectl_file_documents.council.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    kubernetes_config_map.council_config,
    kubectl_manifest.valkey,
    kubectl_manifest.litellm
  ]
}

data "kubectl_file_documents" "openwebui" {
  content = file("${path.module}/k8s/openwebui.yaml")
}

resource "kubectl_manifest" "openwebui" {
  for_each  = data.kubectl_file_documents.openwebui.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    kubernetes_secret.ai_platform_secrets,
    kubectl_manifest.litellm,
    kubectl_manifest.tika
  ]
}
