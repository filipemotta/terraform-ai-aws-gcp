output "rds_instance" {
  description = "The RDS instance object. master_user_secret carries the Secrets Manager ARN of the generated password."
  value       = aws_db_instance.this
  sensitive   = true
}

output "rds_endpoint" {
  description = "host:port of the PostgreSQL instance, for application configuration."
  value       = aws_db_instance.this.endpoint
}

output "rds_security_group_id" {
  description = "Security group of the instance; workloads that need a tighter rule than the VPC CIDR reference it."
  value       = aws_security_group.this.id
}

output "app_bucket" {
  description = "The application bucket object."
  value       = aws_s3_bucket.this
}
