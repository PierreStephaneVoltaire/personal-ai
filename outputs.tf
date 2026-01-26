output "kubeconfig_command" {
  value = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.main.name}"
}

output "database_uri" {
  value     = digitalocean_database_cluster.postgres.uri
  sensitive = true
}

output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.main.endpoint
}

output "gateway_loadbalancer_ip" {
  description = "Run this command to get the LoadBalancer IP for DNS configuration"
  value       = "kubectl get gateway main-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}'"
}

output "dns_records_needed" {
  description = "DNS A records to create in Namecheap"
  value       = <<-EOT
    After terraform apply, create these A records in Namecheap:

    1. Get the LoadBalancer IP:
       kubectl get gateway main-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}'

    2. In Namecheap DNS settings for ${var.domain}:
       - Host: litellm  | Type: A | Value: <LB_IP> | TTL: Automatic
       - Host: rancher  | Type: A | Value: <LB_IP> | TTL: Automatic
       - Host: chat     | Type: A | Value: <LB_IP> | TTL: Automatic
       - Host: n8n      | Type: A | Value: <LB_IP> | TTL: Automatic

    TLS certificates will be automatically provisioned by cert-manager once DNS propagates.
  EOT
}

output "parameter_store_paths" {
  description = "AWS Parameter Store paths for credentials"
  value = {
    rancher_bootstrap_password = aws_ssm_parameter.rancher_bootstrap_password.name
    litellm_master_key         = aws_ssm_parameter.litellm_master_key.name
    litellm_ui_username        = aws_ssm_parameter.litellm_ui_username.name
    litellm_ui_password        = aws_ssm_parameter.litellm_ui_password.name
    librechat_jwt_secret       = aws_ssm_parameter.librechat_jwt_secret.name
    n8n_encryption_key         = aws_ssm_parameter.n8n_encryption_key.name
  }
}

output "librechat_url" {
  description = "URL for LibreChat"
  value       = "https://chat.${var.domain}"
}

output "n8n_url" {
  description = "URL for n8n"
  value       = "https://n8n.${var.domain}"
}

output "service_urls" {
  description = "All service URLs"
  value = {
    litellm   = "https://litellm.${var.domain}"
    librechat = "https://chat.${var.domain}"
    n8n       = "https://n8n.${var.domain}"
    rancher   = "https://rancher.${var.domain}"
  }
}
