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

  depends_on = [null_resource.mcp_build]

  metadata {
    name      = "mcp-server"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
    labels = {
      app       = "mcp-server"
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
        app = "mcp-server"
      }
    }

    template {
      metadata {
        labels = {
          app       = "mcp-server"
          component = "mcp-server"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.mcp_sa.metadata[0].name

        image_pull_secrets {
          name = kubernetes_secret.ecr_secret.metadata[0].name
        }
dynamic "container" {
  for_each = var.mcp_servers

  content {
    name = "${replace(container.key, "_", "-")}" 
    image             = coalesce(container.value.image, "${aws_ecr_repository.mcp_server.repository_url}:${local.mcp_build_trigger}")
    image_pull_policy = "Always"

    command = container.value.command
    args    = container.value.args

    port {
      container_port = container.value.port
      name           = "${replace(container.key, "_", "-")}"
    }

    liveness_probe {
      tcp_socket {
        port = "${replace(container.key, "_", "-")}"
      }
      initial_delay_seconds = 30
      period_seconds        = 30
    }

    env {
      name  = "FASTMCP_LOG_LEVEL"
      value = "ERROR"
    }

    # Hardcoded env vars
    env {
      name  = "aws-foundation"
      value = "true"
    }
    env {
      name  = "solutions-architect"
      value = "true"
    }
    env {
      name  = "dev-tools"
      value = "true"
    }
    env {
      name  = "ci-cd-devops"
      value = "true"
    }
    env {
      name  = "sql-db-specialist"
      value = "true"
    }
    env {
      name  = "nosql-db-specialist"
      value = "true"
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

    resources {
      requests = {
        memory = "${floor(2048 / length(var.mcp_servers))}Mi" 
      }
    }
  }
}

     
      }
    }
  }
}

resource "kubernetes_service" "mcp_server" {
  for_each = var.mcp_servers

  metadata {
    name      = "mcp-server-${replace(each.key, "_", "-")}"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }

  spec {
    selector = {
      app = "mcp-server"
    }

    port {
      name        = "${replace(each.key, "_", "-")}"
      port        = each.value.port
      target_port = each.value.port
    }

    type = "ClusterIP"
  }
}
