output "ai_platform_app_name" {
  value = var.deploy_ai_platform ? kubernetes_manifest.ai_platform_app[0].manifest.metadata.name : null
}
