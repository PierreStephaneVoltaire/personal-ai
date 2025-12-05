output "namespace" {
  value = kubernetes_namespace.ai_platform.metadata[0].name
}

output "argocd_namespace" {
  value = var.stopped ? null : helm_release.argocd[0].namespace
}

output "litellm_master_key" {
  value     = random_password.litellm_master_key.result
  sensitive = true
}
