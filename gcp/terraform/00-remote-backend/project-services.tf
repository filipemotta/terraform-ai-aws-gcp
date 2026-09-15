resource "google_project_service" "this" {
  count   = length(var.project.services)
  project = var.impersonation.project_id
  service = var.project.services[count.index]

  disable_on_destroy = false
}
