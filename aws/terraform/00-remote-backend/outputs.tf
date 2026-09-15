output "state_bucket" {
  description = "The state bucket object. Downstream stacks reference its name in their backend and terraform_remote_state blocks."
  value       = aws_s3_bucket.this
}
