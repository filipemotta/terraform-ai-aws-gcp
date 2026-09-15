# Dedicated node identity instead of the Compute Engine default service
# account (which carries roles/editor). Minimum roles for logs, metrics and
# image pulls; workloads get their own identities via Workload Identity.

resource "google_service_account" "node" {
  account_id   = var.gke.node_service_account_id
  display_name = "GKE node service account (atlas)"
}

resource "google_project_iam_member" "node" {
  count   = length(var.gke.node_service_account_roles)
  project = var.impersonation.project_id
  role    = var.gke.node_service_account_roles[count.index]
  member  = "serviceAccount:${google_service_account.node.email}"
}
