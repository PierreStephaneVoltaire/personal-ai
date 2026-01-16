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
    yt_backup_image_url    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.yt_backup.name}"
    cookies_parameter_name = aws_ssm_parameter.youtube_cookies.name
  })
}

# resource "kubectl_manifest" "yt_backup" {
#   for_each  = data.kubectl_file_documents.yt_backup.manifests
#   yaml_body = each.value

#   depends_on = [
#     kubernetes_namespace.ai_platform,
#     kubernetes_secret.aws_creds,
#     aws_ecr_repository.yt_backup
#   ]
# }

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