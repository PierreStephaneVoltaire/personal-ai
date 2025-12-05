output "cluster_id" {
  value = data.rancher2_cluster.main.id
}

output "cluster_name" {
  value = data.rancher2_cluster.main.name
}

output "admin_token" {
  value     = rancher2_bootstrap.admin.token
  sensitive = true
}

output "kubeconfig" {
  value     = data.rancher2_cluster.main.kube_config
  sensitive = true
}

output "kube_host" {
  value     = yamldecode(data.rancher2_cluster.main.kube_config).clusters[0].cluster.server
  sensitive = true
}

output "kube_token" {
  value     = yamldecode(data.rancher2_cluster.main.kube_config).users[0].user.token
  sensitive = true
}
