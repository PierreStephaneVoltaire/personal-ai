resource "kubernetes_namespace" "ai_platform" {
  metadata {
    name = "ai-platform"
    labels = {
      name        = "ai-platform"
      environment = var.environment
    }
  }
}

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}

resource "random_password" "webui_secret_key" {
  length  = 32
  special = false
}

resource "random_password" "mcpo_api_key" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "litellm_master_key" {
  name  = "/ai-platform/${var.environment}/litellm/master-key"
  type  = "SecureString"
  value = random_password.litellm_master_key.result
}

resource "aws_ssm_parameter" "openrouter_api_key" {
  name  = "/ai-platform/${var.environment}/openrouter/api-key"
  type  = "SecureString"
  value = var.openrouter_api_key
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    LITELLM_MASTER_KEY = random_password.litellm_master_key.result
    OPENROUTER_API_KEY = var.openrouter_api_key
    WEBUI_SECRET_KEY   = random_password.webui_secret_key.result
    MCPO_API_KEY       = random_password.mcpo_api_key.result
    DATABASE_URL       = var.database_url
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "litellm_config" {
  metadata {
    name      = "litellm-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      model_list = [
        for model in var.litellm_models : {
          model_name = model.model_name
          litellm_params = {
            model    = "openrouter/${model.model_id}"
            api_base = "https://openrouter.ai/api/v1"
            api_key  = "os.environ/OPENROUTER_API_KEY"
          }
        }
      ]
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY"
      }
    })
  }
}

resource "kubernetes_config_map" "mcpo_config" {
  metadata {
    name      = "mcpo-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.json" = jsonencode({
      mcpServers = {
        time = {
          command = "uvx"
          args    = ["mcp-server-time", "--local-timezone", var.timezone]
        }
        memory = {
          command = "npx"
          args    = ["-y", "@modelcontextprotocol/server-memory"]
        }
      }
    })
  }
}
