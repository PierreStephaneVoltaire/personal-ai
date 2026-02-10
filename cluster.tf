data "digitalocean_kubernetes_versions" "current" {
  version_prefix = "1.34."
}

resource "digitalocean_kubernetes_cluster" "main" {
  name    = "${var.project_name}-cluster"
  region  = var.region
  version = data.digitalocean_kubernetes_versions.current.latest_version

  # Default node pool for system components and ingress
  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 1
    auto_scale = false
    labels = {
      "workload-type" = "system"
    }
  }

  auto_upgrade = true
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}

resource "digitalocean_kubernetes_node_pool" "ai_services_pool" {
  cluster_id = digitalocean_kubernetes_cluster.main.id
  name       = "ai-services-pool"
  size       = "s-2vcpu-4gb"
  node_count = 1
  auto_scale = true
  min_nodes  = 0
  max_nodes  = 2
  labels = {
    "workload-type" = "ai-services"
  }
  taint {
    key    = "dedicated"
    value  = "ai-services"
    effect = "NoSchedule"
  }
}

resource "digitalocean_kubernetes_node_pool" "general_pool" {
  cluster_id = digitalocean_kubernetes_cluster.main.id
  name       = "general-pool"
  size       = "s-2vcpu-4gb"
  node_count = 1
  auto_scale = true
  min_nodes  = 0
  max_nodes  = 4
  labels = {
    "workload-type" = "general"
  }
  taint {
    key    = "dedicated"
    value  = "general"
    effect = "NoSchedule"
  }
}
