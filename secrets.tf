resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    DATABASE_URL = digitalocean_database_cluster.postgres.uri
    DB_HOST      = digitalocean_database_cluster.postgres.host
    DB_PORT      = tostring(digitalocean_database_cluster.postgres.port)
    DB_USER      = digitalocean_database_cluster.postgres.user
    DB_PASSWORD  = digitalocean_database_cluster.postgres.password
    DB_NAME      = digitalocean_database_db.personal_ai.name
  }
}

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    OPENROUTER_API_KEY    = var.openrouter_api_key
    LITELLM_DATABASE_URL  = digitalocean_database_cluster.postgres.uri
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    LITELLM_MASTER_KEY    = data.aws_ssm_parameter.litellm_master_key.value
    UI_USERNAME           = data.aws_ssm_parameter.litellm_ui_username.value
    UI_PASSWORD           = data.aws_ssm_parameter.litellm_ui_password.value
  }

  type = "Opaque"
}

data "aws_ecr_authorization_token" "token" {}

resource "kubernetes_secret" "ecr_secret" {
  metadata {
    name      = "ecr-secret"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${data.aws_ecr_authorization_token.token.proxy_endpoint}" = {
          auth = data.aws_ecr_authorization_token.token.authorization_token
        }
      }
    })
  }
}

resource "kubernetes_secret" "mcp_secrets" {
  metadata {
    name      = "mcp-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    AWS_REGION            = var.aws_region
  }
}

resource "kubernetes_secret" "mongodb_secrets" {
  metadata {
    name      = "mongodb-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    MONGODB_PASSWORD = data.aws_ssm_parameter.mongodb_password.value
  }

  type = "Opaque"
}

resource "kubernetes_secret" "librechat_secrets" {
  metadata {
    name      = "librechat-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    JWT_SECRET         = data.aws_ssm_parameter.librechat_jwt_secret.value
    JWT_REFRESH_SECRET = data.aws_ssm_parameter.librechat_jwt_refresh_secret.value
    CREDS_KEY          = data.aws_ssm_parameter.librechat_creds_key.value
    CREDS_IV           = data.aws_ssm_parameter.librechat_creds_iv.value
    SESSION_SECRET     = data.aws_ssm_parameter.librechat_session_secret.value
    LITELLM_API_KEY    = data.aws_ssm_parameter.litellm_master_key.value
    MONGO_URI          = "mongodb://librechat:${data.aws_ssm_parameter.mongodb_password.value}@mongodb.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local:27017/librechat?authSource=admin"
  }

  type = "Opaque"
}

resource "kubernetes_secret" "n8n_secrets" {
  metadata {
    name      = "n8n-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    N8N_ENCRYPTION_KEY              = data.aws_ssm_parameter.n8n_encryption_key.value
    N8N_USER_MANAGEMENT_JWT_SECRET  = data.aws_ssm_parameter.n8n_jwt_secret.value
    DB_POSTGRESDB_DATABASE          = digitalocean_database_db.n8n.name
    DB_POSTGRESDB_HOST              = digitalocean_database_cluster.postgres.host
    DB_POSTGRESDB_PORT              = tostring(digitalocean_database_cluster.postgres.port)
    DB_POSTGRESDB_USER              = digitalocean_database_cluster.postgres.user
    DB_POSTGRESDB_PASSWORD          = digitalocean_database_cluster.postgres.password
  }

  type = "Opaque"
}
