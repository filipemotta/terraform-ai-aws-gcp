resource "google_compute_network" "main" {
  name                    = var.vpc.name
  auto_create_subnetworks = false
  routing_mode            = var.vpc.routing_mode
}
