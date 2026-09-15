# Private Services Access: reserve an internal range in the VPC and peer it
# with Google's service producer network so Cloud SQL gets a private IP.
# This is the GCP equivalent of the RDS subnet group + VPC-scoped security
# group; there is no security group, the peering is the boundary.

resource "google_compute_global_address" "this" {
  name          = var.sql.peering_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.sql.peering_range_prefix
  network       = local.network_id
}

resource "google_service_networking_connection" "this" {
  network                 = local.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.this.name]
}
