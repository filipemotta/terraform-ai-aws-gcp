# Stack 00-remote-backend: bootstrap. Creates the GCS bucket that hosts the
# Terraform state of every other stack (and, after the first apply, its own),
# and enables the project APIs the downstream stacks call.
#
# Chicken-and-egg: on the very first apply the bucket does not exist yet, so
# the backend block below cannot be initialised. Bootstrap sequence:
#   1. Comment out the `backend "gcs"` block, `terraform init && terraform apply`
#      (state lands in a local terraform.tfstate).
#   2. Uncomment the block and run `terraform init -migrate-state` to move the
#      local state into the bucket it just created.
# See README.md for the full sequence.

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
    prefix = "remote-backend"
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
