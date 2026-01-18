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

resource "kubernetes_config_map" "mcp_config" {
  metadata {
    name      = "mcp-config"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  data = {
    MCP_LOG_LEVEL = "info"
  }
}

resource "kubernetes_deployment" "mcp_server" {
  for_each = var.mcp_servers

  metadata {
    name      = "mcp-server-${replace(each.key, "_", "-")}"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app       = "mcp-server-${replace(each.key, "_", "-")}"
      component = "mcp-server"
    }
  }

  spec {
    replicas = 1
    
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "mcp-server-${replace(each.key, "_", "-")}"
      }
    }

    template {
      metadata {
        labels = {
          app       = "mcp-server-${replace(each.key, "_", "-")}"
          component = "mcp-server"
        }
      }

      spec {
        image_pull_secrets {
          name = kubernetes_secret.ecr_secret.metadata[0].name
        }
        host_network = true
        dns_policy   = "ClusterFirstWithHostNet"

        container {
          name              = "mcp-server"
          image             = coalesce(each.value.image, "${aws_ecr_repository.mcp_server.repository_url}:${local.mcp_build_trigger}")
          image_pull_policy = "Always"

          command = each.value.command
          args    = each.value.args

          port {
            container_port = each.value.port
            name           = "mcp-port"
          }

          liveness_probe {
            exec {
              # Check if the port is listening on localhost
              command = ["/bin/bash", "-c", "nc -z 127.0.0.1 ${each.value.port} || exit 1"]
            }
            initial_delay_seconds = 60
            period_seconds        = 60
          }

          env {
            name  = "KUBECONFIG"
            value = "/root/.kube/config"
          }
          
          env_from {
            secret_ref {
              name = kubernetes_secret.ai_platform_secrets.metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.mcp_secrets.metadata[0].name
            }
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.mcp_config.metadata[0].name
            }
          }

          volume_mount {
            name       = "kubeconfig"
            mount_path = "/root/.kube/config"
            read_only  = true
          }

          dynamic "volume_mount" {
            for_each = var.mcp_filesystem_mount_paths
            content {
              name       = "fs-mount-${volume_mount.key}"
              mount_path = "/mnt/fs/${volume_mount.key}"
            }
          }
        }

        volume {
          name = "kubeconfig"
          host_path {
            path = var.kubeconfig_path
            type = "File"
          }
        }

        dynamic "volume" {
          for_each = var.mcp_filesystem_mount_paths
          content {
            name = "fs-mount-${volume.key}"
            host_path {
              path = volume.value
              type = "Directory"
            }
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.mcp_build
  ]
}

resource "kubernetes_service" "mcp_server" {
  for_each = var.mcp_servers

  metadata {
    name      = "mcp-server-${replace(each.key, "_", "-")}"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  spec {
    selector = {
      app = "mcp-server-${replace(each.key, "_", "-")}"
    }

    port {
      name        = "mcp-port"
      port        = each.value.port
      target_port = each.value.port
    }

    type = "ClusterIP"
  }
}