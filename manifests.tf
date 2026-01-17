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

# ---------------------------------------------------------------------
# Discord Bot Service
# ---------------------------------------------------------------------

resource "kubernetes_secret" "discord_bot_secrets" {
  metadata {
    name      = "discord-bot-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    DISCORD_TOKEN   = var.discord_token
    N8N_WEBHOOK_URL = var.n8n_webhook_url
  }

  type = "Opaque"
}

resource "kubectl_manifest" "discord_bot" {
  yaml_body = templatefile("${path.module}/k8s/discord-bot.yaml", {
    discord_bot_image_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.discord_bot.name}"
  })

  depends_on = [
    kubernetes_namespace.ai_platform,
    kubernetes_secret.discord_bot_secrets,
    aws_ecr_repository.discord_bot
  ]
}

# ---------------------------------------------------------------------
# MCP Server Deployment
# ---------------------------------------------------------------------

data "kubectl_file_documents" "mcp" {
  content = templatefile("${path.module}/k8s/mcp.yaml", {
    namespace         = "ai-platform"
    aws_access_key    = var.aws_access_key
    aws_secret_key    = var.aws_secret_key
    aws_region        = var.aws_region
    image_url         = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/mcp-server"
    kubeconfig_path   = var.kubeconfig_path
    filesystem_mounts = var.mcp_filesystem_mount_paths
  })
}

resource "kubectl_manifest" "mcp" {
  for_each  = data.kubectl_file_documents.mcp.manifests
  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.ai_platform,
    aws_ecr_repository.mcp_server
  ]
}
