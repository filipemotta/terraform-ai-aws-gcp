# 00-remote-backend

## Purpose
Bootstrap stack: creates the GCS bucket that stores the state of every stack in this repository and enables the project APIs the other stacks need.

## Provisions
- `google_storage_bucket.this` (versioning on, uniform bucket-level access, public access prevention enforced)
- `google_project_service.this[*]` (compute, container, servicenetworking, sqladmin, iam, iamcredentials)

## Consumes (from upstream stacks)
- none (this is stack zero)

## Provides (for downstream stacks)
- `state_bucket` ... its name is hard-coded in every `backend "gcs"` and `terraform_remote_state` block (01-networking, 02-gke, 03-data)
- `enabled_services`

## Bootstrap sequence (chicken-and-egg)
1. Comment out the `backend "gcs"` block in `main.tf`.
2. `terraform workspace new sandbox && terraform init && terraform plan -out tfplan` (agent) and `terraform apply tfplan` (human).
3. Uncomment the backend block and run `terraform init -migrate-state`; answer `yes` to copy the local state into the bucket.
4. Delete the local `terraform.tfstate*` files once the migration is confirmed.

## What changed from the AWS stack
- One resource instead of four: versioning, encryption and public-access blocking are bucket arguments in GCS, not separate resources.
- The state object path is `<prefix>/<workspace>.tfstate`; there is no `key`.
- Project APIs must be enabled before 01-03 can run; on AWS there is no equivalent step.
