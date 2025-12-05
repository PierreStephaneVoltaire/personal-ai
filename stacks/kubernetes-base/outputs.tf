output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = helm_release.cert_manager.namespace
}

output "nginx_gateway_namespace" {
  description = "Nginx gateway namespace"
  value       = helm_release.nginx_gateway_fabric.namespace
}
