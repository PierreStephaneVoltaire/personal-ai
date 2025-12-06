output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = helm_release.cert_manager.namespace
}

