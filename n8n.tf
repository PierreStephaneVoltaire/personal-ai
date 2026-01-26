# ---------------------------------------------------------------------
# n8n Deployment
# ---------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "n8n_data" {
  metadata {
    name      = "n8n-data-pvc"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app = "n8n"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "n8n"
      }
    }

    template {
      metadata {
        labels = {
          app = "n8n"
        }
      }

      spec {
        security_context {
          fs_group = 1000
        }

        container {
          name              = "n8n"
          image             = "n8nio/n8n:latest"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5678
            protocol       = "TCP"
            name           = "http"
          }

          security_context {
            run_as_user  = 1000
            run_as_group = 1000
          }

          # Database configuration
          env {
            name  = "DB_TYPE"
            value = "postgresdb"
          }

          env {
            name = "DB_POSTGRESDB_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "DB_POSTGRESDB_DATABASE"
              }
            }
          }

          env {
            name = "DB_POSTGRESDB_HOST"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "DB_POSTGRESDB_HOST"
              }
            }
          }

          env {
            name = "DB_POSTGRESDB_PORT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "DB_POSTGRESDB_PORT"
              }
            }
          }

          env {
            name = "DB_POSTGRESDB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "DB_POSTGRESDB_USER"
              }
            }
          }

          env {
            name = "DB_POSTGRESDB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "DB_POSTGRESDB_PASSWORD"
              }
            }
          }

          env {
            name  = "DB_POSTGRESDB_SSL_ENABLED"
            value = "true"
          }

          env {
            name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
            value = "false"
          }

          # Encryption and security
          env {
            name = "N8N_ENCRYPTION_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "N8N_ENCRYPTION_KEY"
              }
            }
          }

          env {
            name = "N8N_USER_MANAGEMENT_JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.n8n_secrets.metadata[0].name
                key  = "N8N_USER_MANAGEMENT_JWT_SECRET"
              }
            }
          }

          # Port configuration (must be set explicitly to avoid K8s service env var conflict)
          env {
            name  = "N8N_PORT"
            value = "5678"
          }

          # Host and URL configuration
          env {
            name  = "N8N_HOST"
            value = "n8n.${var.domain}"
          }

          env {
            name  = "N8N_PROTOCOL"
            value = "https"
          }

          env {
            name  = "WEBHOOK_URL"
            value = "https://n8n.${var.domain}/"
          }

          env {
            name  = "N8N_EDITOR_BASE_URL"
            value = "https://n8n.${var.domain}/"
          }

          # Execution settings
          env {
            name  = "EXECUTIONS_DATA_SAVE_ON_SUCCESS"
            value = "all"
          }

          env {
            name  = "EXECUTIONS_DATA_SAVE_ON_ERROR"
            value = "all"
          }

          env {
            name  = "EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS"
            value = "true"
          }

          env {
            name  = "EXECUTIONS_DATA_PRUNE"
            value = "true"
          }

          env {
            name  = "EXECUTIONS_DATA_MAX_AGE"
            value = "336"
          }

          # Timezone
          env {
            name  = "GENERIC_TIMEZONE"
            value = "America/New_York"
          }

          env {
            name  = "TZ"
            value = "America/New_York"
          }

          # Logging
          env {
            name  = "N8N_LOG_LEVEL"
            value = "info"
          }

          env {
            name  = "N8N_LOG_OUTPUT"
            value = "console"
          }

          # Metrics
          env {
            name  = "N8N_METRICS"
            value = "false"
          }

          # Queue mode (disabled for single instance)
          env {
            name  = "EXECUTIONS_MODE"
            value = "regular"
          }

          # Basic auth (optional)
          dynamic "env" {
            for_each = var.n8n_basic_auth_active ? [1] : []
            content {
              name  = "N8N_BASIC_AUTH_ACTIVE"
              value = "true"
            }
          }

          dynamic "env" {
            for_each = var.n8n_basic_auth_active ? [1] : []
            content {
              name  = "N8N_BASIC_AUTH_USER"
              value = var.n8n_basic_auth_user
            }
          }

          dynamic "env" {
            for_each = var.n8n_basic_auth_active ? [1] : []
            content {
              name  = "N8N_BASIC_AUTH_PASSWORD"
              value = var.n8n_basic_auth_password
            }
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = 5678
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
              path   = "/healthz"
              port   = 5678
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 5
          }

          volume_mount {
            mount_path = "/home/node/.n8n"
            name       = "n8n-data"
          }
        }

        volume {
          name = "n8n-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.n8n_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  spec {
    selector = {
      app = "n8n"
    }

    port {
      port        = 5678
      target_port = 5678
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
