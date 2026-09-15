# 00-remote-backend

## Purpose
Bootstrap stack: creates the S3 bucket that stores the state of every stack in this repository.

## Provisions
- `aws_s3_bucket.this` (versioning enabled, SSE-S3 encryption, all public access blocked)

## Consumes (from upstream stacks)
- none (this is stack zero)

## Provides (for downstream stacks)
- `state_bucket` ... its name is hard-coded in every `backend "s3"` and `terraform_remote_state` block (01-networking, 02-eks, 03-data)

## Bootstrap sequence (chicken-and-egg)
1. Comment out the `backend "s3"` block in `main.tf`.
2. `terraform workspace new sandbox && terraform init && terraform plan -out tfplan` (agent) and `terraform apply tfplan` (human).
3. Uncomment the backend block and run `terraform init -migrate-state`; answer `yes` to copy the local state into the bucket.
4. Delete the local `terraform.tfstate*` files once the migration is confirmed.
