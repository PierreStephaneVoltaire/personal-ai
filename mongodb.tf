# ---------------------------------------------------------------------
# MongoDB for LibreChat
# ---------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "mongodb_data" {
  metadata {
    name      = "mongodb-data-pvc"
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

resource "kubernetes_deployment" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
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
          name              = "mongodb"
          image             = "mongo:7"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 27017
            protocol       = "TCP"
          }

          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = "librechat"
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb_secrets.metadata[0].name
                key  = "MONGODB_PASSWORD"
              }
            }
          }

          env {
            name  = "MONGO_INITDB_DATABASE"
            value = "librechat"
          }

        resources {
          requests = {
            memory = "512Mi"     
            cpu    = "50m"       
          }
          limits = {
            memory = "1Gi"       
            cpu    = "1000m"      
          }
        }

        
liveness_probe {
  exec {
    command = ["mongosh", "--eval", "db.adminCommand('ping')"]
  }
  initial_delay_seconds = 60        # Increased from 30
  period_seconds        = 15        # Increased from 10
  failure_threshold     = 5         # Increased from 3
  timeout_seconds       = 10        # Increased from 5
}

readiness_probe {
  exec {
    command = ["mongosh", "--eval", "db.adminCommand('ping')"]
  }
  initial_delay_seconds = 30        # Increased from 10
  period_seconds        = 10        # Increased from 5
  failure_threshold     = 5         # Increased from 3
  timeout_seconds       = 10        # Increased from 5
}
          volume_mount {
            mount_path = "/data/db"
            name       = "mongodb-data"
          }
        }

        volume {
          name = "mongodb-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongodb_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
