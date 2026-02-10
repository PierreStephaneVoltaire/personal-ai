# ---------------------------------------------------------------------
# LibreChat Deployment
# ---------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "librechat_data" {
  metadata {
    name      = "librechat-data-pvc"
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

resource "kubernetes_config_map" "librechat_config" {
  metadata {
    name      = "librechat-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    "librechat.yaml" = yamlencode({
      version = "1.1.5"
      cache   = true

      # Interface configuration
      interface = {
        privacyPolicy = {
          externalUrl = "https://chat.${var.domain}/privacy"
          openNewTab  = true
        }
        termsOfService = {
          externalUrl = "https://chat.${var.domain}/terms"
          openNewTab  = true
        }
        # Enable UI features
        modelSelect = true
        parameters  = true
        sidePanel   = true
        prompts     = true
        bookmarks   = true
        multiConvo  = true
        agents      = true
        runCode     = true
        fileSearch  = true
      }

      # Registration and authentication
      registration = {
        socialLogins = []
      }

      # Endpoints configuration
      endpoints = {
        custom = [
          {
            name    = "LiteLLM"
            apiKey  = "$${LITELLM_API_KEY}"
            baseURL = "http://litellm.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local:4000/v1"
            models = {
              default = [
                for model in var.litellm_models : model.model_name
              ]
              fetch = true
            }
            titleConvo        = true
            titleModel        = var.litellm_models[0].model_name
            summarize         = false
            summaryModel      = var.litellm_models[0].model_name
            forcePrompt       = false
            modelDisplayLabel = "LiteLLM"
            addParams = {
              max_tokens = 4096
            }
          }
        ]
      }

      # File configuration - restricted to code files only
      fileConfig = {
        endpoints = {
          assistants = {
            fileLimit      = 10
            fileSizeLimit  = 10
            totalSizeLimit = 100
            supportedMimeTypes = [
              # Code files
              "text/x-typescript",
              "text/x-javascript",
              "text/x-python",
              "text/x-java",
              "text/x-c",
              "text/x-c++",
              "text/x-csharp",
              "text/x-go",
              "text/x-rust",
              "text/x-ruby",
              "text/x-php",
              "text/x-swift",
              "text/x-kotlin",
              "text/x-scala",
              "text/x-groovy",
              "text/x-shell",
              "text/x-bash",
              "text/x-powershell",
              # Config/Data files
              "application/json",
              "application/xml",
              "text/xml",
              "application/yaml",
              "text/yaml",
              "text/x-yaml",
              "application/toml",
              "text/x-toml",
              # Terraform
              "text/x-terraform",
              "application/x-terraform",
              # Markdown and text
              "text/markdown",
              "text/plain",
              # Web files
              "text/html",
              "text/css",
              "text/javascript",
              "application/javascript",
              # Generic patterns for code files
              "text/.*",
              "application/.*script"
            ]
          }
          openAI = {
            disabled = true
          }
          default = {
            totalSizeLimit = 50
          }
        }
        serverFileSizeLimit = 100
        avatarSizeLimit     = 2
      }

      # MCP Settings - allowed domains for MCP server connections
      mcpSettings = {
        allowedDomains = [
          # Kubernetes internal services
          "*.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local"
        ]
      }

      # MCP Servers - direct connections to MCP servers in cluster
      mcpServers = merge(
        {
          # SSE type servers (exclude fetch and time as they'll be stdio)
          for key, val in var.mcp_servers : key => {
            type = "sse"
            url  = "http://mcp-server-${replace(key, "_", "-")}.${kubernetes_namespace.ai_platform.metadata[0].name}.svc.cluster.local:${val.port}/sse"
          }

        },
        {
          # STDIO type servers (run in container)
          sequential_thinking = {
            type    = "stdio"
            startup = false # Disable auto-start to prevent OAuth reconnect issues
            command = "npx"
            args = [
              "-y",
              "@modelcontextprotocol/server-sequential-thinking"
            ]
            serverInstructions = "Use this server for complex reasoning and step-by-step problem solving"
          }

          finance_tools = {
            type    = "stdio"
            startup = false # Disable auto-start to prevent OAuth reconnect issues
            command = "uvx"
            args    = ["finance-tools-mcp"]
          }
        }
      )

      # Rate limiting
      rateLimits = {
        fileUploads = {
          ipMax          = 100
          ipWindowInMs   = 60000
          userMax        = 50
          userWindowInMs = 60000
        }
        conversationsImport = {
          ipMax          = 100
          ipWindowInMs   = 60000
          userMax        = 50
          userWindowInMs = 60000
        }
      }

      # Memory configuration
      memory = {
        disabled          = false
        messageWindowSize = 5
        personalize       = true
        agent = {
          provider = "LiteLLM"
          model    = "gpt-5.2-codex"
        }
      }
    })
  }
}

resource "kubernetes_deployment" "librechat" {
  depends_on = [kubernetes_service.mongodb]

  lifecycle {
    replace_triggered_by = [kubernetes_config_map.librechat_config]
  }

  metadata {
    name      = "librechat"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app = "librechat"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "librechat"
      }
    }

    template {
      metadata {
        labels = {
          app = "librechat"
        }
      }

      spec {
        node_selector = {
          "workload-type" = "general"
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "general"
          effect   = "NoSchedule"
        }

        container {
          name              = "librechat"
          image             = "ghcr.io/danny-avila/librechat:latest"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 3080
            protocol       = "TCP"
          }

          # Environment variables
          env {
            name  = "HOST"
            value = "0.0.0.0"
          }

          env {
            name  = "PORT"
            value = "3080"
          }

          env {
            name = "MONGO_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "MONGO_URI"
              }
            }
          }

          env {
            name  = "DOMAIN_CLIENT"
            value = "https://chat.${var.domain}"
          }

          env {
            name  = "DOMAIN_SERVER"
            value = "https://chat.${var.domain}"
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          env {
            name = "JWT_REFRESH_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "JWT_REFRESH_SECRET"
              }
            }
          }

          env {
            name = "CREDS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "CREDS_KEY"
              }
            }
          }

          env {
            name = "CREDS_IV"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "CREDS_IV"
              }
            }
          }

          env {
            name = "SESSION_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "SESSION_SECRET"
              }
            }
          }

          env {
            name = "LITELLM_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.librechat_secrets.metadata[0].name
                key  = "LITELLM_API_KEY"
              }
            }
          }

          env {
            name  = "APP_TITLE"
            value = var.librechat_app_title
          }

          env {
            name  = "ALLOW_EMAIL_LOGIN"
            value = "true"
          }


          env {
            name  = "ALLOW_SOCIAL_LOGIN"
            value = "false"
          }

          env {
            name  = "ALLOW_SOCIAL_REGISTRATION"
            value = "false"
          }

          env {
            name  = "DEBUG_LOGGING"
            value = "false"
          }

          env {
            name  = "DEBUG_CONSOLE"
            value = "false"
          }

          env {
            name  = "CONFIG_PATH"
            value = "/app/librechat.yaml"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "1024Mi"
              cpu    = "800m"
            }
          }

          liveness_probe {
            http_get {
              path   = "/api/health"
              port   = 3080
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path   = "/api/health"
              port   = 3080
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 5
          }

          volume_mount {
            mount_path = "/app/librechat.yaml"
            name       = "config"
            sub_path   = "librechat.yaml"
          }

          volume_mount {
            mount_path = "/app/client/public/images"
            name       = "librechat-data"
            sub_path   = "images"
          }

          volume_mount {
            mount_path = "/app/api/logs"
            name       = "librechat-data"
            sub_path   = "logs"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.librechat_config.metadata[0].name
          }
        }

        volume {
          name = "librechat-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.librechat_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "librechat" {
  metadata {
    name      = "librechat"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  spec {
    selector = {
      app = "librechat"
    }

    port {
      port        = 3080
      target_port = 3080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
