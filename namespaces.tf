resource "kubernetes_namespace" "ai_platform" {
  metadata {
    name = "ai-platform"
    labels = {
      name        = "ai-platform"
      environment = var.environment
    }
  }
}

resource "kubernetes_namespace" "dev_sandboxes" {
  metadata {
    name = "dev-sandboxes"
    labels = {
      name        = "dev-sandboxes"
      environment = var.environment
    }
  }
}
