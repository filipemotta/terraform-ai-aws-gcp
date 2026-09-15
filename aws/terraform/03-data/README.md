# 03-data

## Purpose
The data floor: a single-AZ PostgreSQL instance on the private subnets, reachable only from the VPC, and the application object bucket.

## Provisions
- `aws_db_subnet_group.this` (private subnets of 01-networking)
- `aws_security_group.this` + `aws_vpc_security_group_ingress_rule.this` (5432 from the VPC CIDR)
- `aws_db_instance.this` (PostgreSQL 18, db.t4g.micro, 20 GiB gp3, encrypted, RDS-managed master password)
- `aws_s3_bucket.this` + versioning, SSE-S3, public access block

## Consumes (from upstream stacks)
- `01-networking` via `data.terraform_remote_state.network`: `vpc` (id, cidr_block), `private_subnets_ids`

## Provides (for downstream stacks)
- `rds_endpoint`, `rds_security_group_id`, `app_bucket` ... for an application stack
- `rds_instance` (sensitive)

## Notes
- POC values are explicit in `var.rds`: `deletion_protection = false`, `skip_final_snapshot = true`, `multi_az = false`, `backup_retention_period = 1`. Production flips all four.
- The master password never enters Terraform state in clear text: `manage_master_user_password = true` keeps it in Secrets Manager.
