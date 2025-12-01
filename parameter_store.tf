# =============================================================================
# OpenRouter Configuration
# =============================================================================
resource "aws_ssm_parameter" "openrouter_api_key" {
  name        = "/${var.project_name}/openrouter/api_key"
  description = "OpenRouter API key"
  type        = "SecureString"
  value       = var.openrouter_api_key

  tags = {
    Name = "${var.project_name}-openrouter-api-key"
  }
}

resource "aws_ssm_parameter" "openrouter_base_url" {
  name        = "/${var.project_name}/openrouter/base_url"
  description = "OpenRouter base URL"
  type        = "String"
  value       = var.openrouter_base_url

  tags = {
    Name = "${var.project_name}-openrouter-base-url"
  }
}

# =============================================================================
# LiteLLM Configuration
# =============================================================================
resource "random_password" "litellm_master_key" {
  count   = var.litellm_master_key == "" ? 1 : 0
  length  = 32
  special = false
}

locals {
  litellm_master_key = var.litellm_master_key != "" ? var.litellm_master_key : random_password.litellm_master_key[0].result
}

resource "aws_ssm_parameter" "litellm_master_key" {
  name        = "/${var.project_name}/litellm/master_key"
  description = "LiteLLM master key"
  type        = "SecureString"
  value       = local.litellm_master_key

  tags = {
    Name = "${var.project_name}-litellm-master-key"
  }
}

resource "aws_ssm_parameter" "litellm_models" {
  name        = "/${var.project_name}/litellm/models"
  description = "LiteLLM model configuration (JSON)"
  type        = "String"
  value       = jsonencode(var.litellm_models)

  tags = {
    Name = "${var.project_name}-litellm-models"
  }
}

resource "aws_ssm_parameter" "default_model" {
  name        = "/${var.project_name}/litellm/default_model"
  description = "Default model for LiteLLM"
  type        = "String"
  value       = var.default_model

  tags = {
    Name = "${var.project_name}-default-model"
  }
}

resource "aws_ssm_parameter" "system_prompt" {
  name        = "/${var.project_name}/config/system_prompt"
  description = "Default system prompt"
  type        = "String"
  tier        = "Advanced" 
  value       = var.system_prompt

  tags = {
    Name = "${var.project_name}-system-prompt"
  }
}

# =============================================================================
# OpenWebUI Configuration
# =============================================================================
resource "random_password" "openwebui_admin_password" {
  count   = var.openwebui_admin_password == "" ? 1 : 0
  length  = 24
  special = true
  override_special = "!@#$%^&*"
}

locals {
  openwebui_admin_password = var.openwebui_admin_password != "" ? var.openwebui_admin_password : random_password.openwebui_admin_password[0].result
}

resource "aws_ssm_parameter" "openwebui_admin_email" {
  name        = "/${var.project_name}/openwebui/admin_email"
  description = "OpenWebUI admin email"
  type        = "String"
  value       = var.openwebui_admin_email

  tags = {
    Name = "${var.project_name}-openwebui-admin-email"
  }
}

resource "aws_ssm_parameter" "openwebui_admin_password" {
  name        = "/${var.project_name}/openwebui/admin_password"
  description = "OpenWebUI admin password"
  type        = "SecureString"
  value       = local.openwebui_admin_password

  tags = {
    Name = "${var.project_name}-openwebui-admin-password"
  }
}

resource "aws_ssm_parameter" "openwebui_admin_name" {
  name        = "/${var.project_name}/openwebui/admin_name"
  description = "OpenWebUI admin display name"
  type        = "String"
  value       = var.openwebui_admin_name

  tags = {
    Name = "${var.project_name}-openwebui-admin-name"
  }
}
