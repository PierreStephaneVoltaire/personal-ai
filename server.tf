# server.tf

# ---------------------------------------------------------------------
# 1. Local K3s Configuration
# ---------------------------------------------------------------------

# We assume K3s is installed manually and the config is available/readable at this path.
# Run scripts/install_k3s.sh manually before applying this.
locals {
  kubeconfig_path = "${path.module}/kubeconfig"
}

# ---------------------------------------------------------------------
# 2. Kubernetes Providers
# ---------------------------------------------------------------------

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "kubectl" {
  config_path      = local.kubeconfig_path
  load_config_file = true
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

# ---------------------------------------------------------------------
# 3. Rancher & Cert-Manager Installation
# ---------------------------------------------------------------------

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.0"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  namespace        = "cattle-system"
  create_namespace = true

  set {
    name  = "hostname"
    value = "rancher.local"
  }

  set {
    name  = "bootstrapPassword"
    value = "admin"
  }

  set {
    name  = "replicas"
    value = "1"
  }

  depends_on = [helm_release.cert_manager]
}

# ---------------------------------------------------------------------
# 4. Base Resources & Secrets
# ---------------------------------------------------------------------

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

resource "random_password" "n8n_password" {
  length  = 32
  special = true
}

resource "aws_ssm_parameter" "litellm_master_key" {
  name        = "/${var.project_name}/${var.environment}/litellm/master-key"
  description = "LiteLLM Master Key"
  type        = "SecureString"
  value       = "sk-${random_password.litellm_master_key.result}"

  tags = {
    Name        = "litellm-master-key"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "litellm_ui_password" {
  name        = "/${var.project_name}/${var.environment}/litellm/ui-password"
  description = "LiteLLM UI Password"
  type        = "SecureString"
  value       = "sk-${random_password.litellm_master_key.result}"

  tags = {
    Name        = "litellm-ui-password"
    Environment = var.environment
  }
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    OPENROUTER_API_KEY     = var.openrouter_api_key
    LITELLM_DATABASE_URL   = replace(var.litellm_database_url, "/@[^@/]+:[0-9]+\\//", "@127.0.0.1:5432/")
    # Legacy keys if needed, but updated to use new variables
    AWS_ACCESS_KEY_ID      = var.aws_access_key
    AWS_SECRET_ACCESS_KEY  = var.aws_secret_key
    LITELLM_MASTER_KEY     = "sk-${random_password.litellm_master_key.result}"
    UI_USERNAME            = "admin"
    UI_PASSWORD            = "sk-${random_password.litellm_master_key.result}"
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

resource "kubernetes_config_map" "litellm_config" {
  metadata {
    name      = "litellm-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      general_settings = {
        store_model_in_db = true
        master_key        = "os.environ/LITELLM_MASTER_KEY"
      }
      litellm_settings = {
        mcp_aliases = {
          "fs"         = "filesystem"
          "aws"        = "aws_docs"
          "terraform"  = "terraform"
          "eks"        = "eks"
          "ecs"        = "ecs"
          "serverless" = "serverless"
          "k8s"        = "kubernetes"
          "cost"       = "cost_explorer"
          "cloudwatch" = "cloudwatch"
          "bedrock"    = "bedrock"
          "pricing"    = "pricing"
          "billing"    = "billing"
          "iac"        = "iac"
          "core"       = "core"
        }
      }
      mcp_servers = {
        for key, val in var.mcp_servers : key => {
          url = "http://mcp-server-${key}.ai-platform.svc.cluster.local:${val.port}"
        }
      }
      model_list = concat(
        [
          for model in var.litellm_models : {
            model_name = model.model_name
            litellm_params = {
              model    = length(regexall("^ollama/", model.model_id)) > 0 ? model.model_id : "openrouter/${model.model_id}"
              api_base = length(regexall("^ollama/", model.model_id)) > 0 ? "http://localhost:11434" : "https://openrouter.ai/api/v1"
              api_key  = length(regexall("^ollama/", model.model_id)) > 0 ? "none" : "os.environ/OPENROUTER_API_KEY"
            }
          }
        ]
      )
    })
  }
}
