# Cloud NAT is regional and Google-managed: no EIP, no per-AZ placement.
# This is the single NAT of the AWS stack, without the single-AZ trade-off.

resource "google_compute_router_nat" "this" {
  name                               = var.vpc.nat_name
  router                             = google_compute_router.this.name
  region                             = google_compute_router.this.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = var.vpc.nat_log_filter
  }
}
