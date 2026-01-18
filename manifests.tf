
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



# ---------------------------------------------------------------------
# n8n Deployment
# ---------------------------------------------------------------------

data "kubectl_file_documents" "n8n" {
  content = templatefile("${path.module}/k8s/n8n.yaml", {
    n8n_password    = random_password.n8n_password.result
    n8n_db_password = var.n8n_db_password
    postgres_host   = var.postgres_host
    postgres_port   = var.postgres_port
  })
}

resource "kubectl_manifest" "n8n" {
  for_each  = data.kubectl_file_documents.n8n.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    random_password.n8n_password
  ]
}



