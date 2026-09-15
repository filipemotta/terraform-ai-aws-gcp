resource "google_container_node_pool" "this" {
  name           = var.gke.node_pool.name
  cluster        = google_container_cluster.this.id
  location       = var.impersonation.region
  node_locations = var.gke.node_locations
  node_count     = var.gke.node_pool.node_count

  management {
    auto_repair  = var.gke.node_pool.auto_repair
    auto_upgrade = var.gke.node_pool.auto_upgrade
  }

  node_config {
    machine_type    = var.gke.node_pool.machine_type
    disk_size_gb    = var.gke.node_pool.disk_size_gb
    disk_type       = var.gke.node_pool.disk_type
    service_account = google_service_account.node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
