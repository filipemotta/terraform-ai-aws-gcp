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

variable "sql" {
  description = "PostgreSQL instance on private IP. No password in state: the application authenticates with IAM as the service account created here."
  type = object({
    instance_name              = string
    database_version           = string
    tier                       = string
    edition                    = string
    availability_type          = string
    disk_size                  = number
    disk_type                  = string
    database_name              = string
    app_service_account_id     = string
    backup_enabled             = bool
    peering_range_name         = string
    peering_range_prefix       = number
    deletion_protection        = bool
    deletion_protection_in_gcp = bool
  })

  default = {
    instance_name    = "sql-postgres-atlas-uscentral1"
    database_version = "POSTGRES_18"
    tier             = "db-f1-micro"
    # PostgreSQL 16+ defaults to ENTERPRISE_PLUS, which rejects shared-core
    # tiers such as db-f1-micro; ENTERPRISE must be explicit.
    edition                = "ENTERPRISE"
    availability_type      = "ZONAL"
    disk_size              = 10
    disk_type              = "PD_SSD"
    database_name          = "atlas"
    app_service_account_id = "app-atlas"
    backup_enabled         = true
    peering_range_name     = "psa-range-atlas-uscentral1"
    peering_range_prefix   = 16
    # POC values: a production stack sets both to true.
    deletion_protection        = false
    deletion_protection_in_gcp = false
  }
}

variable "app_bucket" {
  description = "Application object storage. Name must be globally unique."
  type = object({
    name          = string
    location      = string
    storage_class = string
    force_destroy = bool
  })

  default = {
    name          = "atlas-us-central1-bucket-app-data"
    location      = "us-central1"
    storage_class = "STANDARD"
    force_destroy = true
  }
}
