output "gke_cluster" {
  description = "The GKE cluster object (endpoint, master_auth, workload_identity_config)."
  value       = google_container_cluster.this
  sensitive   = true
}

output "cluster_name" {
  description = "Cluster name, for kubeconfig generation (gcloud container clusters get-credentials --region)."
  value       = google_container_cluster.this.name
}

output "node_pool" {
  description = "The node pool object."
  value       = google_container_node_pool.this
}

output "node_service_account_email" {
  description = "Email of the node service account. A later add-ons stack may grant it more roles."
  value       = google_service_account.node.email
}
