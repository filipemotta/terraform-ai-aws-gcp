# 03-data

## Purpose
The data floor: a single-zone PostgreSQL instance reachable only on a private IP inside the VPC, an IAM-authenticated application identity, and the application object bucket.

## Provisions
- `google_compute_global_address.this` + `google_service_networking_connection.this` (Private Services Access peering)
- `google_sql_database_instance.this` (PostgreSQL 18, db-f1-micro, ENTERPRISE edition, 10 GB PD_SSD, private IP only, backups on, IAM auth on)
- `google_sql_database.this`
- `google_service_account.app` + `google_project_iam_member.app` (roles/cloudsql.instanceUser) + `google_sql_user.app` (CLOUD_IAM_SERVICE_ACCOUNT)
- `google_storage_bucket.this` (versioning, uniform access, public access prevention)

## Consumes (from upstream stacks)
- `01-networking` via `data.terraform_remote_state.network`: `network` (id, self_link)

## Provides (for downstream stacks)
- `sql_private_ip_address`, `sql_connection_name`, `app_service_account_email`, `app_bucket` ... for an application stack
- `sql_instance` (sensitive)

## What changed from the AWS stack (resource by resource)
| AWS (03-data)                                                  | GCP (03-data)                                                          |
|----------------------------------------------------------------|------------------------------------------------------------------------|
| `aws_db_subnet_group.this` (private subnets)                   | `google_compute_global_address.this` + `google_service_networking_connection.this` |
| `aws_security_group.this` + ingress rule (5432 from VPC CIDR)  | none: private IP via peering is the boundary; `ipv4_enabled = false`   |
| `aws_db_instance.this` `db.t4g.micro`, gp3 20 GiB              | `google_sql_database_instance.this` `db-f1-micro`, PD_SSD 10 GB        |
| `engine = postgres`, `engine_version = "18"`                   | `database_version = "POSTGRES_18"` + `edition = "ENTERPRISE"` (required for shared-core tiers) |
| `manage_master_user_password = true` (Secrets Manager)         | IAM database authentication: `google_sql_user.app` of type `CLOUD_IAM_SERVICE_ACCOUNT` |
| `storage_encrypted = true`                                     | default (Google-managed encryption); CMEK would use `encryption_key_name` |
| `deletion_protection` / `skip_final_snapshot`                  | `deletion_protection` (Terraform) + `deletion_protection_enabled` (API) |
| `aws_s3_bucket.this` + versioning + SSE + public access block  | `google_storage_bucket.this` (all four are arguments of one resource)  |

## Notes
- POC values are explicit in `var.sql`: `deletion_protection = false`, `deletion_protection_in_gcp = false`, `availability_type = "ZONAL"`. Production flips all three.
- The `depends_on` on the peering connection is mandatory: Cloud SQL does not interpolate it.
