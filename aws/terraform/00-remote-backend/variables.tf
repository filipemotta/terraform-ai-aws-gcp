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

variable "remote_backend" {
  description = "State bucket configuration. bucket_name must match the backend block of every stack."
  type = object({
    name          = string
    sse_algorithm = string
    force_destroy = bool
  })

  default = {
    name          = "atlas-us-east-1-bucket-terraform-state"
    sse_algorithm = "AES256"
    force_destroy = false
  }
}
