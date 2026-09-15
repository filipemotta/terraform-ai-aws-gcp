resource "google_compute_subnetwork" "this" {
  name                     = var.vpc.subnetwork.name
  network                  = google_compute_network.main.id
  region                   = var.impersonation.region
  ip_cidr_range            = var.vpc.subnetwork.ip_cidr_range
  private_ip_google_access = var.vpc.subnetwork.private_ip_google_access

  dynamic "secondary_ip_range" {
    for_each = var.vpc.subnetwork.secondary_ip_ranges

    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}
