output "cluster_name" {
  value = local.cluster_name
}


output "k3s_server_ip" {
  value = "127.0.0.1"
}

output "rds_endpoint" {
  value = "postgres.default.svc.cluster.local"
}

output "rds_database_name" {
  value = "aiplatform"
}

output "db_connection_string" {
  value     = "postgresql://aiplatform:${random_password.db_password.result}@postgres.default.svc.cluster.local:5432/aiplatform"
  sensitive = true
}

output "s3_bucket" {
  value = aws_s3_bucket.ai_storage.id
}

output "aws_region" {
  value = var.aws_region
}

output "yt_backup_service_endpoint" {
  value       = "http://yt-backup.ai-platform.svc.cluster.local:8080"
  description = "Internal Kubernetes service endpoint for yt-backup"
}

output "n8n_service_endpoint" {
  value       = "http://n8n.ai-platform.svc.cluster.local:5678"
  description = "Internal Kubernetes service endpoint for n8n"
}

output "n8n_url" {
  value       = "http://localhost:30678"
  description = "External n8n URL"
}

output "rancher_url" {
  value       = "https://rancher.local"
  description = "Rancher UI URL"
}

output "litellm_master_key_parameter" {
  value       = aws_ssm_parameter.litellm_master_key.name
  description = "SSM parameter name for LiteLLM master key"
}