output "ai_platform_app_name" {
  value =  kubernetes_manifest.ai_platform_app.manifest.metadata.name 
}
