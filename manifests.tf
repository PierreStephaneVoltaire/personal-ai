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

data "kubectl_file_documents" "mcp_rbac" {
  content = file("${path.module}/k8s/mcp-server-rbac.yaml")
}

resource "kubectl_manifest" "mcp_rbac" {
  for_each  = data.kubectl_file_documents.mcp_rbac.manifests
  yaml_body = each.value

  depends_on = [kubernetes_namespace.ai_platform]
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

# ---------------------------------------------------------------------
# n8n Deployment
# ---------------------------------------------------------------------

data "kubectl_file_documents" "n8n" {
  content = templatefile("${path.module}/k8s/n8n.yaml", {
    n8n_password = random_password.n8n_password.result
    n8n_secrets  = var.n8n_secrets
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

# ---------------------------------------------------------------------
# YouTube Backup Service
# ---------------------------------------------------------------------

# Secret for yt-backup (mirrors aws credentials)
resource "kubernetes_secret" "aws_creds" {
  metadata {
    name      = "n8n-aws-creds"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
  }

  type = "Opaque"
}

data "kubectl_file_documents" "yt_backup" {
  content = templatefile("${path.module}/k8s/yt-backup.yaml", {
    yt_backup_image_url    = aws_ecr_repository.yt_backup.repository_url
    cookies_parameter_name = aws_ssm_parameter.youtube_cookies.name
  })
}

resource "kubectl_manifest" "yt_backup" {
  for_each  = data.kubectl_file_documents.yt_backup.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    kubernetes_secret.aws_creds,
    aws_ecr_repository.yt_backup
  ]
}
