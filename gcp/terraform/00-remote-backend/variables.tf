variable "labels" {
  description = "Global labels injected by the provider default_labels argument. Resources add nothing else; their identity is the name argument."
  type        = map(string)

  default = {
    "project"    = "atlas"
    "env"        = "sandbox"
    "region"     = "us-central1"
    "managed_by" = "terraform"
  }
}

variable "impersonation" {
  description = "Project, region and fallback service account for the provider. service_account is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    project_id      = string
    region          = string
    service_account = string
  })

  default = {
    project_id      = "atlas-demo-123"
    region          = "us-central1"
    service_account = "terraform-plan@atlas-demo-123.iam.gserviceaccount.com"
  }
}

variable "remote_backend" {
  description = "State bucket configuration. name must match the backend block of every stack."
  type = object({
    name          = string
    location      = string
    storage_class = string
    force_destroy = bool
  })

  default = {
    name          = "atlas-us-central1-bucket-terraform-state"
    location      = "us-central1"
    storage_class = "STANDARD"
    force_destroy = false
  }
}

variable "project" {
  description = "Project-level bootstrap: the APIs the downstream stacks call."
  type = object({
    services = list(string)
  })

  default = {
    services = [
      "compute.googleapis.com",
      "container.googleapis.com",
      "servicenetworking.googleapis.com",
      "sqladmin.googleapis.com",
      "iam.googleapis.com",
      "iamcredentials.googleapis.com",
    ]
  }
}
