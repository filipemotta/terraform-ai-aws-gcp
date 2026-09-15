resource "google_container_cluster" "this" {
  name                = var.gke.cluster_name
  location            = var.impersonation.region
  node_locations      = var.gke.node_locations
  network             = local.network_id
  subnetwork          = local.subnetwork_id
  networking_mode     = "VPC_NATIVE"
  datapath_provider   = var.gke.datapath_provider
  deletion_protection = var.gke.deletion_protection

  # The default node pool is removed right after creation; the real pool is
  # google_container_node_pool.this, managed independently.
  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_range_name
    services_secondary_range_name = local.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = var.gke.enable_private_nodes
    enable_private_endpoint = var.gke.enable_private_endpoint
    master_ipv4_cidr_block  = var.gke.master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${var.impersonation.project_id}.svc.id.goog"
  }

  release_channel {
    channel = var.gke.release_channel
  }
}
