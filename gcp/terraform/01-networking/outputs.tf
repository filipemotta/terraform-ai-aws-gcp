output "network" {
  description = "The VPC network object. Consumed by 02-gke and 03-data."
  value       = google_compute_network.main
}

output "subnetwork" {
  description = "The regional subnetwork object (id, self_link, ip_cidr_range, secondary_ip_range)."
  value       = google_compute_subnetwork.this
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods. Consumed by 02-gke ip_allocation_policy."
  value       = google_compute_subnetwork.this.secondary_ip_range[0].range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE services. Consumed by 02-gke ip_allocation_policy."
  value       = google_compute_subnetwork.this.secondary_ip_range[1].range_name
}

output "router" {
  description = "The Cloud Router object."
  value       = google_compute_router.this
}

output "nat" {
  description = "The Cloud NAT object."
  value       = google_compute_router_nat.this
}
