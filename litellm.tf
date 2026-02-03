resource "kubernetes_persistent_volume_claim" "litellm_data" {
  metadata {
    name      = "litellm-data-pvc"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
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
        store_model_in_db           = true
        store_prompts_in_spend_logs = true
        default_fallbacks           = ["general"]
        cache                       = true
        cache_params                = { type = "local" }
        #         s3_bucket_name: cache-bucket-litellm # AWS Bucket Name for S3
        # s3_region_name: us-west-2 # AWS Region Name for S3
        # s3_aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID # us os.environ/<variable name> to pass environment variables. This is AWS Access Key ID for S3
        # s3_aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY # AWS Secret Access Key for S3
        # s3_endpoint_url: https://s3.amazonaws.com # [OPTIONAL] S3 endpoint URL, if you want to use Backblaze/cloudflare s3 bucket

        master_key = "os.environ/LITELLM_MASTER_KEY"
        # vector_db_type              = "pgvector"
        # vector_db_url               = "os.environ/DATABASE_URL"

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
        enable_semantic_cache = true
        cache_ttl             = 3600
      }
      mcp_servers = merge({
        for key, val in var.mcp_servers : key => {
          url       = "http://mcp-server-${replace(key, "_", "-")}.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local:${val.port}/sse"
          transport = "sse"
          startup   = false
        }
      }, var.additional_mcps)
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
    })
  }
}

resource "kubernetes_deployment" "litellm" {
  lifecycle {
    replace_triggered_by = [kubernetes_config_map.litellm_config]
  }
  metadata {
    name      = "litellm"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app = "litellm"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "litellm"
      }
    }
    template {
      metadata {
        labels = {
          app = "litellm"
        }
      }
      spec {
        node_selector = {
          "workload-type" = "ai-services"
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "ai-services"
          effect   = "NoSchedule"
        }

        container {
          name              = "litellm"
          image             = "ghcr.io/berriai/litellm:main-latest"
          image_pull_policy = "IfNotPresent"
          args              = ["--config", "/app/config.yaml", "--port", "4000"]

          port {
            container_port = 4000
            protocol       = "TCP"
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "LITELLM_DATABASE_URL"
              }
            }
          }
          env {
            name = "OPENROUTER_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "OPENROUTER_API_KEY"
              }
            }
          }
          env {
            name  = "OPENAI_API_KEY"
            value = "dummy-key"
          }
  
          env {
            name = "LITELLM_MASTER_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "LITELLM_MASTER_KEY"
              }
            }
          }
          env {
            name = "UI_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "UI_USERNAME"
              }
            }
          }
          env {
            name = "UI_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ai_platform_secrets.metadata[0].name
                key  = "UI_PASSWORD"
              }
            }
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "10m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health/liveliness"
              port   = 4000
              scheme = "HTTP"
              http_header {
                name  = "Authorization"
                value = "Bearer ${data.aws_ssm_parameter.litellm_master_key.value}"
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 1
          }

          readiness_probe {
            http_get {
              path   = "/health/readiness"
              port   = 4000
              scheme = "HTTP"
              http_header {
                name  = "Authorization"
                value = "Bearer ${data.aws_ssm_parameter.litellm_master_key.value}"
              }
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 1
          }

          volume_mount {
            mount_path = "/app/config.yaml"
            name       = "config"
            sub_path   = "config.yaml"
          }
          volume_mount {
            mount_path = "/app/data"
            name       = "litellm-data"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.litellm_config.metadata[0].name
          }
        }
        volume {
          name = "litellm-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.litellm_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "litellm" {
  metadata {
    name      = "litellm"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
  spec {
    selector = {
      app = "litellm"
    }
    port {
      port        = 4000
      target_port = 4000
    }
    type = "ClusterIP"
  }
}
