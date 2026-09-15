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

variable "vpc" {
  description = "Network layout. One regional subnet replaces the AWS public/private pairs; secondary ranges feed GKE (VPC-native). Cloud NAT gives private nodes egress."
  type = object({
    name         = string
    routing_mode = string
    subnetwork = object({
      name                     = string
      ip_cidr_range            = string
      private_ip_google_access = bool
      secondary_ip_ranges = list(object({
        range_name    = string
        ip_cidr_range = string
      }))
    })
    router_name    = string
    nat_name       = string
    nat_log_filter = string
  })

  default = {
    name         = "vpc-atlas-uscentral1"
    routing_mode = "REGIONAL"
    subnetwork = {
      name                     = "subnet-atlas-uscentral1"
      ip_cidr_range            = "10.20.0.0/20"
      private_ip_google_access = true
      secondary_ip_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.21.0.0/16"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.22.0.0/20"
        },
      ]
    }
    router_name    = "router-atlas-uscentral1"
    nat_name       = "nat-atlas-uscentral1"
    nat_log_filter = "ERRORS_ONLY"
  }
}
