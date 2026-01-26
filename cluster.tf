data "digitalocean_kubernetes_versions" "current" {
  version_prefix = "1.32."
}

resource "digitalocean_kubernetes_cluster" "main" {
  name    = "${var.project_name}-cluster"
  region  = var.region
  version = data.digitalocean_kubernetes_versions.current.latest_version

  node_pool {
    name       = "worker-pool"
    size       = "s-4vcpu-8gb"
    node_count = 2
    auto_scale = false
  }

  auto_upgrade = true
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}

# resource "digitalocean_kubernetes_node_pool" "secondary_pool" {
#   cluster_id = digitalocean_kubernetes_cluster.main.id
#   name       = "secondary-pool"
#   size       = "s-2vcpu-4gb"
#   node_count = 0
#   auto_scale = false
# }
