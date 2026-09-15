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

variable "gke" {
  description = "Cluster, node pool and node identity configuration. node_locations lists the zones (the AWS AZ pair); node_count is per zone."
  type = object({
    cluster_name               = string
    node_locations             = list(string)
    release_channel            = string
    datapath_provider          = string
    enable_private_nodes       = bool
    enable_private_endpoint    = bool
    master_ipv4_cidr_block     = string
    deletion_protection        = bool
    node_service_account_id    = string
    node_service_account_roles = list(string)
    node_pool = object({
      name         = string
      machine_type = string
      disk_size_gb = number
      disk_type    = string
      node_count   = number
      auto_repair  = bool
      auto_upgrade = bool
    })
  })

  default = {
    cluster_name            = "gke-cluster-atlas"
    node_locations          = ["us-central1-a", "us-central1-b"]
    release_channel         = "REGULAR"
    datapath_provider       = "ADVANCED_DATAPATH"
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.23.0.0/28"
    # POC value: a production stack sets deletion_protection = true.
    deletion_protection     = false
    node_service_account_id = "gke-node-atlas"
    node_service_account_roles = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/artifactregistry.reader",
    ]
    node_pool = {
      name         = "gke-node-pool-atlas"
      machine_type = "e2-small"
      disk_size_gb = 20
      disk_type    = "pd-balanced"
      node_count   = 1
      auto_repair  = true
      auto_upgrade = true
    }
  }
}
