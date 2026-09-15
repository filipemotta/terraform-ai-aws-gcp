# The application connects with IAM database authentication as this service
# account (Workload Identity binds it to a Kubernetes service account later).
# Nothing here is a secret, so nothing sensitive lands in state.

resource "google_service_account" "app" {
  account_id   = var.sql.app_service_account_id
  display_name = "Application database identity (atlas)"
}

resource "google_project_iam_member" "app" {
  project = var.impersonation.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_sql_user" "app" {
  # Postgres requires the service account email without ".gserviceaccount.com".
  name     = trimsuffix(google_service_account.app.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.this.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
