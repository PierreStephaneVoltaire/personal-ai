output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = helm_release.cert_manager.namespace
}

output "argocd_namespace" {
  description = "ArgoCD namespace name"
  value       = kubernetes_namespace.argocd.metadata[0].name
}