resource "google_compute_router" "this" {
  name    = var.vpc.router_name
  network = google_compute_network.main.id
  region  = var.impersonation.region
}
