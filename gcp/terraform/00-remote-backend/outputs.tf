output "state_bucket" {
  description = "The state bucket object. Downstream stacks reference its name in their backend and terraform_remote_state blocks."
  value       = google_storage_bucket.this
}

output "enabled_services" {
  description = "Project APIs enabled by this stack."
  value       = google_project_service.this[*].service
}
