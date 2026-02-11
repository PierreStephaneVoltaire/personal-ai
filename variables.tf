variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "project_name" {
  type    = string
  default = "ai-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

# AWS Credentials for ECR/Bedrock etc.
variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

# API Keys
variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

# LiteLLM Configuration
variable "litellm_models" {
  type = list(object({
    model_name        = string
    model_id          = string
    temperature       = number
    top_p             = optional(number)
    frequency_penalty = optional(number)
    presence_penalty  = optional(number)
    reasoning_effort  = optional(string)
  }))
  default = []
}

# Flow-tier routing: maps model_name to flow-tier combinations
# App calls LiteLLM with "{flow}-{tier}" (e.g., "consensus-tier2")
# LiteLLM simple-shuffle routes to any model in this list
variable "flow_tier_models" {
  description = "Explicit mapping of flow-tier model groups to model names"
  type        = map(list(string))
  default     = {}
}

# MCP Configuration
# Domain Configuration
variable "domain" {
  description = "Base domain for services (e.g., barelycompetent.xyz)"
  type        = string
  default     = "barelycompetent.xyz"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "rancher_bootstrap_password" {
  description = "Bootstrap password for Rancher admin"
  type        = string
  sensitive   = true
  default     = "admin"
}
variable "additional_mcps" {
  description = "Map of MCP servers to deploy"


  type = map(object({
    url            = string
    transport      = string
    authentication = string
  }))
  default = {

  }
}
variable "mcp_servers" {
  description = "Map of MCP servers to deploy"
  type = map(object({
    port    = number
    command = list(string)
    args    = list(string)
    image   = optional(string)
  }))
}

# LibreChat Configuration
variable "librechat_app_title" {
  description = "Application title for LibreChat"
  type        = string
  default     = "AI Chat Platform"
}

# n8n Configuration
variable "n8n_basic_auth_active" {
  description = "Enable basic auth for n8n"
  type        = bool
  default     = false
}

variable "n8n_basic_auth_user" {
  description = "Basic auth username for n8n"
  type        = string
  default     = ""
  sensitive   = true
}

variable "n8n_basic_auth_password" {
  description = "Basic auth password for n8n"
  type        = string
  default     = ""
  sensitive   = true
}
