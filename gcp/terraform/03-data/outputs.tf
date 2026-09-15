output "sql_instance" {
  description = "The Cloud SQL instance object."
  value       = google_sql_database_instance.this
  sensitive   = true
}

output "sql_private_ip_address" {
  description = "Private IP of the PostgreSQL instance, for application configuration."
  value       = google_sql_database_instance.this.private_ip_address
}

output "sql_connection_name" {
  description = "project:region:instance, for the Cloud SQL Auth Proxy / connectors."
  value       = google_sql_database_instance.this.connection_name
}

output "app_service_account_email" {
  description = "Service account the application uses for IAM database authentication; bind it with Workload Identity."
  value       = google_service_account.app.email
}

output "app_bucket" {
  description = "The application bucket object."
  value       = google_storage_bucket.this
}
