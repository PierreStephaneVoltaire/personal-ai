variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "project_name" {
  type    = string
  default = "ai-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}


variable "timezone" {
  type    = string
  default = "America/Toronto"
}

variable "litellm_models" {
  type = list(object({
    model_name  = string
    model_id    = string
    max_tokens  = number
    temperature = number
  }))
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}





variable "aws_access_key" {

  type = string

  sensitive = true

}



variable "aws_secret_key" {

  type = string

  sensitive = true

}

variable "mcp_filesystem_mount_paths" {
  description = "List of host paths to mount into the MCP server container for the filesystem server"
  type        = list(string)
  default     = []
}

variable "discord_token" {
  type      = string
  sensitive = true
}

variable "n8n_webhook_url" {
  type      = string
  sensitive = true
}

# PostgreSQL connection variables
variable "postgres_host" {
  default = "172.17.0.1"
}

variable "postgres_port" {
  default = 5432
}

variable "n8n_db_password" {
  sensitive = true
}

variable "n8n_database_url" {
  sensitive = true
}

variable "openwebui_database_url" {
  sensitive = true
}

variable "litellm_database_url" {
  sensitive = true
}

variable "jenkins_database_url" {
  sensitive = true
}