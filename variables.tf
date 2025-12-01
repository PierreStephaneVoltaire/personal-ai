# =============================================================================
# General Configuration
# =============================================================================
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "openwebui-litellm"
}

# =============================================================================
# Networking Configuration
# =============================================================================
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the services (default: open to all)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# EC2 Configuration
# =============================================================================
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "spot_max_price" {
  description = "Maximum spot price (empty string means on-demand price)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

# =============================================================================
# Cost Monitoring Configuration
# =============================================================================
variable "enable_budget_alerts" {
  description = "Enable AWS Budget alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 50
}

variable "budget_alert_emails" {
  description = "Email addresses to notify for budget alerts"
  type        = list(string)
  default     = []
}

# =============================================================================
# RDS Configuration
# =============================================================================
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "aiplatform"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "app"
}

# =============================================================================
# OpenRouter Configuration
# =============================================================================
variable "openrouter_api_key" {
  description = "OpenRouter API key"
  type        = string
  sensitive   = true
}

variable "openrouter_base_url" {
  description = "OpenRouter API base URL"
  type        = string
  default     = "https://openrouter.ai/api/v1"
}

# =============================================================================
# LiteLLM Configuration
# =============================================================================
variable "litellm_master_key" {
  description = "LiteLLM master key for API access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "litellm_models" {
  description = "List of models to configure in LiteLLM"
  type = list(object({
    model_name       = string
    litellm_provider = string
    model_id         = string
  }))
  default = [
    {
      model_name       = "mistral-medium"
      litellm_provider = "openrouter"
      model_id         = "mistralai/mistral-medium"
    },
    {
      model_name       = "claude-3-opus"
      litellm_provider = "openrouter"
      model_id         = "anthropic/claude-3-opus"
    },
    {
      model_name       = "claude-3-sonnet"
      litellm_provider = "openrouter"
      model_id         = "anthropic/claude-3-sonnet"
    },
    {
      model_name       = "gpt-4-turbo"
      litellm_provider = "openrouter"
      model_id         = "openai/gpt-4-turbo"
    }
  ]
}

variable "default_model" {
  description = "Default model for LiteLLM"
  type        = string
  default     = "mistralai/mistral-medium"
}

variable "system_prompt" {
  description = "Default system prompt"
  type        = string
  default     = "You are a helpful AI assistant."
}

# =============================================================================
# OpenWebUI Configuration
# =============================================================================
variable "openwebui_admin_email" {
  description = "OpenWebUI admin email"
  type        = string
  default     = "admin@example.com"
}

variable "openwebui_admin_password" {
  description = "OpenWebUI admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openwebui_admin_name" {
  description = "OpenWebUI admin display name"
  type        = string
  default     = "Admin"
}

# =============================================================================
# Service Ports
# =============================================================================
variable "openwebui_port" {
  description = "Port for OpenWebUI"
  type        = number
  default     = 3000
}

variable "litellm_port" {
  description = "Port for LiteLLM"
  type        = number
  default     = 4000
}
