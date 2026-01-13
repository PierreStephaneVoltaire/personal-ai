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

resource "random_password" "webui_secret_key" {
  length  = 32
  special = false
}

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
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

resource "aws_ssm_parameter" "openwebui_email" {
  name        = "/${var.project_name}/${var.environment}/openwebui/email"
  description = "OpenWebUI Admin Email"
  type        = "String"
  value       = "admin"

  tags = {
    Name        = "openwebui-email"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "openwebui_password" {
  name        = "/${var.project_name}/${var.environment}/openwebui/password"
  description = "OpenWebUI Admin Password"
  type        = "SecureString"
  value       = "sk-${random_password.litellm_master_key.result}"

  tags = {
    Name        = "openwebui-password"
    Environment = var.environment
  }
}

resource "kubernetes_secret" "ai_platform_secrets" {
  metadata {
    name      = "ai-platform-secrets"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    OPENROUTER_API_KEY = var.openrouter_api_key
    WEBUI_SECRET_KEY   = random_password.webui_secret_key.result
    # Point to the local postgres service (deployed in rds.tf)
    DATABASE_URL          = "postgres://aiplatform:${random_password.db_password.result}@postgres.default.svc.cluster.local:5432/aiplatform"
    POSTGRES_USER         = "aiplatform"
    POSTGRES_PASSWORD     = random_password.db_password.result
    POSTGRES_DB           = "aiplatform"
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    LITELLM_MASTER_KEY    = "sk-${random_password.litellm_master_key.result}"
    UI_USERNAME           = "admin"
    UI_PASSWORD           = "sk-${random_password.litellm_master_key.result}"
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
      model_list = concat(
        [
          for model in var.litellm_models : {
            model_name = model.model_name
            litellm_params = {
              model    = "openrouter/${model.model_id}"
              api_base = "https://openrouter.ai/api/v1"
              api_key  = "os.environ/OPENROUTER_API_KEY"
            }
          }
        ]
      )
      mcp_servers = {
        kubernetes = {
          transport        = "stdio"
          command          = "npx"
          args             = ["-y", "kubernetes-mcp-server@latest", "--kubeconfig", "/etc/kubernetes/kubeconfig"]
          require_approval = "never"
        }
      }
    })
  }
}
