variable "tags" {
  description = "Global tags injected by the provider default_tags block. Resources only add Name."
  type        = map(string)

  default = {
    "Project"   = "atlas"
    "Env"       = "sandbox"
    "region"    = "us-east-1"
    "ManagedBy" = "terraform"
  }
}
variable "assume_role" {
  description = "Region and fallback role for the provider. role_arn is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    role_arn = string
    region   = string
  })

  default = {
    role_arn = "arn:aws:iam::123456789012:role/terraform-plan-readonly"
    region   = "us-east-1"
  }
}

variable "rds" {
  description = "PostgreSQL instance. Master password is generated and stored by RDS in Secrets Manager (manage_master_user_password)."
  type = object({
    identifier              = string
    engine                  = string
    engine_version          = string
    instance_class          = string
    allocated_storage       = number
    storage_type            = string
    db_name                 = string
    username                = string
    port                    = number
    multi_az                = bool
    backup_retention_period = number
    subnet_group_name       = string
    security_group_name     = string
    deletion_protection     = bool
    skip_final_snapshot     = bool
  })

  default = {
    identifier              = "rds-postgres-atlas-useast1"
    engine                  = "postgres"
    engine_version          = "18"
    instance_class          = "db.t4g.micro"
    allocated_storage       = 20
    storage_type            = "gp3"
    db_name                 = "atlas"
    username                = "atlas_admin"
    port                    = 5432
    multi_az                = false
    backup_retention_period = 1
    subnet_group_name       = "rds-subnet-group-atlas-useast1"
    security_group_name     = "rds-security-group-atlas-useast1"
    # POC values: a production stack sets deletion_protection = true and
    # skip_final_snapshot = false. Left explicit so the diff is visible.
    deletion_protection = false
    skip_final_snapshot = true
  }
}

variable "app_bucket" {
  description = "Application object storage. Name must be globally unique."
  type = object({
    name          = string
    sse_algorithm = string
    force_destroy = bool
  })

  default = {
    name          = "atlas-us-east-1-bucket-app-data"
    sse_algorithm = "AES256"
    force_destroy = true
  }
}
