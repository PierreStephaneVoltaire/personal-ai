resource "kubernetes_service_account" "mcp_sa" {
  metadata {
    name      = "mcp-sa"
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
}

# ClusterRole with full access except secrets (read + create only for secrets)
resource "kubernetes_cluster_role" "mcp_read_role" {
  metadata {
    name = "mcp-read-role"
  }

  # Secrets - read and create only (no edit/delete)
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "create"]
  }

  # Core API resources - full access
  rule {
    api_groups = [""]
    resources = [
      "namespaces",
      "pods",
      "pods/log",
      "pods/status",
      "pods/exec",
      "services",
      "endpoints",
      "configmaps",
      "persistentvolumeclaims",
      "persistentvolumes",
      "events",
      "serviceaccounts",
      "replicationcontrollers",
      "resourcequotas",
      "limitranges"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Nodes - read only (typically shouldn't modify nodes)
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  # Apps API resources - full access
  rule {
    api_groups = ["apps"]
    resources = [
      "deployments",
      "daemonsets",
      "replicasets",
      "statefulsets"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Batch API resources - full access
  rule {
    api_groups = ["batch"]
    resources = [
      "jobs",
      "cronjobs"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Networking API resources - full access
  rule {
    api_groups = ["networking.k8s.io"]
    resources = [
      "ingresses",
      "networkpolicies",
      "ingressclasses"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # RBAC API resources - full access
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "roles",
      "rolebindings",
      "clusterroles",
      "clusterrolebindings"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Storage API resources - full access
  rule {
    api_groups = ["storage.k8s.io"]
    resources = [
      "storageclasses",
      "volumeattachments"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Autoscaling API resources - full access
  rule {
    api_groups = ["autoscaling"]
    resources = [
      "horizontalpodautoscalers"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Policy API resources - full access
  rule {
    api_groups = ["policy"]
    resources = [
      "poddisruptionbudgets"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "mcp_read_binding" {
  metadata {
    name = "mcp-read-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.mcp_read_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.mcp_sa.metadata[0].name
    namespace = kubernetes_namespace.ai_platform.metadata[0].name
  }
}
