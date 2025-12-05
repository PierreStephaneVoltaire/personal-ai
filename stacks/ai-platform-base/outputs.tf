output "namespace" {
  value = kubernetes_namespace.ai_platform.metadata[0].name
}

output "litellm_master_key" {
  value     = random_password.litellm_master_key.result
  sensitive = true
}
