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
        default_fallbacks           = ["kimi-k2.5"]
        cache                       = true
        cache_params                = { type = "local" }
        master_key                  = "os.environ/LITELLM_MASTER_KEY"
      }
      router_settings = {
        enable_tag_filtering    = true
        routing_strategy        = "simple-shuffle"
        tag_filtering_match_any = false
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
      # Model list: flow-tier routing + direct access
      model_list = concat(
        # Flow-tier routing: generate entries from explicit flow_tier_models map
        flatten([
          for flow_tier, model_names in var.flow_tier_models : [
            for name in model_names : {
              model_name = flow_tier
              litellm_params = {
                model       = "openrouter/${local.model_lookup[name].model_id}"
                api_base    = "https://openrouter.ai/api/v1"
                api_key     = "os.environ/OPENROUTER_API_KEY"
                temperature = local.model_lookup[name].temperature
                top_p       = try(local.model_lookup[name].top_p, 0.9)
              }
            }
          ]
        ]),
        # Direct model access: each model can be called by its model_name
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

# Model lookup: map model_name to model object for flow-tier routing
locals {
  model_lookup = { for m in var.litellm_models : m.model_name => m }
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
