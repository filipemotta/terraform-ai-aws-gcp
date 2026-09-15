# Stack 02-gke: regional GKE Standard cluster with private nodes, Workload
# Identity, one small node pool on a dedicated service account. Network from 01.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # GCS locks natively and encrypts at rest by default: no lock table, no
  # `encrypt`/`use_lockfile` switches. The state object is
  # <prefix>/<workspace>.tfstate, so the workspace name, not the stack name,
  # ends the path. Backend access uses the ambient credentials (ADC) or
  # GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT; see iam/plan-only-role.md.
  backend "gcs" {
    bucket = "atlas-us-central1-bucket-terraform-state"
    prefix = "gke"
  }
}

# Workspace-aware identity selection: production is plan-only for the agent.
# The hard guardrail lives in IAM (see iam/plan-only-role.md), not here.
# Any workspace not listed here (including "default", the one a fresh
# `terraform init` lands in) falls back to var.impersonation.service_account,
# which defaults to the plan-only account: unknown workspaces fail closed.
locals {
  workspace_service_account = {
    sandbox    = "terraform-apply@atlas-demo-123.iam.gserviceaccount.com"
    staging    = "terraform-apply@atlas-demo-123.iam.gserviceaccount.com"
    production = "terraform-plan@atlas-demo-123.iam.gserviceaccount.com"
  }
}

provider "google" {
  project        = var.impersonation.project_id
  region         = var.impersonation.region
  default_labels = var.labels

  impersonate_service_account = lookup(local.workspace_service_account, terraform.workspace, var.impersonation.service_account)
}
