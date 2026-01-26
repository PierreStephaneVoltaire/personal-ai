# ---------------------------------------------------------------------
# AWS Systems Manager Parameter Store
# ---------------------------------------------------------------------

# Rancher Bootstrap Password
resource "aws_ssm_parameter" "rancher_bootstrap_password" {
  name        = "/${var.project_name}/${var.environment}/rancher/bootstrap-password"
  description = "Bootstrap password for Rancher admin"
  type        = "SecureString"
  value       = var.rancher_bootstrap_password

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# LiteLLM Master Key
resource "aws_ssm_parameter" "litellm_master_key" {
  name        = "/${var.project_name}/${var.environment}/litellm/master-key"
  description = "Master key for LiteLLM API authentication"
  type        = "SecureString"
  value       = "sk-${random_password.litellm_master_key.result}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# LiteLLM UI Username
resource "aws_ssm_parameter" "litellm_ui_username" {
  name        = "/${var.project_name}/${var.environment}/litellm/ui-username"
  description = "Username for LiteLLM UI"
  type        = "String"
  value       = "admin"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# LiteLLM UI Password
resource "aws_ssm_parameter" "litellm_ui_password" {
  name        = "/${var.project_name}/${var.environment}/litellm/ui-password"
  description = "Password for LiteLLM UI"
  type        = "SecureString"
  value       = "sk-${random_password.litellm_master_key.result}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------
# Data Sources to retrieve parameters
# ---------------------------------------------------------------------

data "aws_ssm_parameter" "rancher_bootstrap_password" {
  name       = aws_ssm_parameter.rancher_bootstrap_password.name
  depends_on = [aws_ssm_parameter.rancher_bootstrap_password]
}

data "aws_ssm_parameter" "litellm_master_key" {
  name       = aws_ssm_parameter.litellm_master_key.name
  depends_on = [aws_ssm_parameter.litellm_master_key]
}

data "aws_ssm_parameter" "litellm_ui_username" {
  name       = aws_ssm_parameter.litellm_ui_username.name
  depends_on = [aws_ssm_parameter.litellm_ui_username]
}

data "aws_ssm_parameter" "litellm_ui_password" {
  name       = aws_ssm_parameter.litellm_ui_password.name
  depends_on = [aws_ssm_parameter.litellm_ui_password]
}

# ---------------------------------------------------------------------
# MongoDB Secrets
# ---------------------------------------------------------------------

resource "random_password" "mongodb_password" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "mongodb_password" {
  name        = "/${var.project_name}/${var.environment}/mongodb/password"
  description = "MongoDB root password for LibreChat"
  type        = "SecureString"
  value       = random_password.mongodb_password.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------
# LibreChat Secrets
# ---------------------------------------------------------------------

resource "random_password" "librechat_jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "librechat_jwt_refresh_secret" {
  length  = 32
  special = false
}

resource "random_password" "librechat_creds_key" {
  length  = 32
  special = false
}

resource "random_password" "librechat_creds_iv" {
  length  = 16
  special = false
}

resource "random_password" "librechat_session_secret" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "librechat_jwt_secret" {
  name        = "/${var.project_name}/${var.environment}/librechat/jwt-secret"
  description = "JWT signing secret for LibreChat"
  type        = "SecureString"
  value       = random_password.librechat_jwt_secret.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "librechat_jwt_refresh_secret" {
  name        = "/${var.project_name}/${var.environment}/librechat/jwt-refresh-secret"
  description = "JWT refresh token secret for LibreChat"
  type        = "SecureString"
  value       = random_password.librechat_jwt_refresh_secret.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "librechat_creds_key" {
  name        = "/${var.project_name}/${var.environment}/librechat/creds-key"
  description = "Credentials encryption key for LibreChat"
  type        = "SecureString"
  value       = random_password.librechat_creds_key.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "librechat_creds_iv" {
  name        = "/${var.project_name}/${var.environment}/librechat/creds-iv"
  description = "Credentials encryption IV for LibreChat"
  type        = "SecureString"
  value       = random_password.librechat_creds_iv.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "librechat_session_secret" {
  name        = "/${var.project_name}/${var.environment}/librechat/session-secret"
  description = "Session secret for LibreChat"
  type        = "SecureString"
  value       = random_password.librechat_session_secret.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------
# n8n Secrets
# ---------------------------------------------------------------------

resource "random_password" "n8n_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "n8n_jwt_secret" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "n8n_encryption_key" {
  name        = "/${var.project_name}/${var.environment}/n8n/encryption-key"
  description = "Encryption key for n8n"
  type        = "SecureString"
  value       = random_password.n8n_encryption_key.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "n8n_jwt_secret" {
  name        = "/${var.project_name}/${var.environment}/n8n/jwt-secret"
  description = "JWT secret for n8n user management"
  type        = "SecureString"
  value       = random_password.n8n_jwt_secret.result

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------
# Data Sources for LibreChat and n8n
# ---------------------------------------------------------------------

data "aws_ssm_parameter" "librechat_jwt_secret" {
  name       = aws_ssm_parameter.librechat_jwt_secret.name
  depends_on = [aws_ssm_parameter.librechat_jwt_secret]
}

data "aws_ssm_parameter" "librechat_jwt_refresh_secret" {
  name       = aws_ssm_parameter.librechat_jwt_refresh_secret.name
  depends_on = [aws_ssm_parameter.librechat_jwt_refresh_secret]
}

data "aws_ssm_parameter" "librechat_creds_key" {
  name       = aws_ssm_parameter.librechat_creds_key.name
  depends_on = [aws_ssm_parameter.librechat_creds_key]
}

data "aws_ssm_parameter" "librechat_creds_iv" {
  name       = aws_ssm_parameter.librechat_creds_iv.name
  depends_on = [aws_ssm_parameter.librechat_creds_iv]
}

data "aws_ssm_parameter" "librechat_session_secret" {
  name       = aws_ssm_parameter.librechat_session_secret.name
  depends_on = [aws_ssm_parameter.librechat_session_secret]
}

data "aws_ssm_parameter" "n8n_encryption_key" {
  name       = aws_ssm_parameter.n8n_encryption_key.name
  depends_on = [aws_ssm_parameter.n8n_encryption_key]
}

data "aws_ssm_parameter" "n8n_jwt_secret" {
  name       = aws_ssm_parameter.n8n_jwt_secret.name
  depends_on = [aws_ssm_parameter.n8n_jwt_secret]
}

data "aws_ssm_parameter" "mongodb_password" {
  name       = aws_ssm_parameter.mongodb_password.name
  depends_on = [aws_ssm_parameter.mongodb_password]
}
