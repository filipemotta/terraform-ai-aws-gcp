output "vpc" {
  description = "The VPC object. Consumed by 02-eks (cluster VPC) and 03-data (security group scope, cidr_block)."
  value       = aws_vpc.main
}

output "internet_gateway" {
  description = "The internet gateway object."
  value       = aws_internet_gateway.this
}

output "nat_gateway" {
  description = "The NAT gateway object."
  value       = aws_nat_gateway.this
}

output "public_subnets_ids" {
  description = "IDs of the public subnets, in AZ order. Consumed by 02-eks (cluster endpoint ENIs)."
  value       = aws_subnet.public[*].id
}

output "private_subnets_ids" {
  description = "IDs of the private subnets, in AZ order. Consumed by 02-eks (node group) and 03-data (DB subnet group)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_arn" {
  description = "ARNs of the public subnets."
  value       = aws_subnet.public[*].arn
}

output "private_subnet_arn" {
  description = "ARNs of the private subnets."
  value       = aws_subnet.private[*].arn
}
