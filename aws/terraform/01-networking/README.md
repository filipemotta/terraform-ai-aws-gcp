# 01-networking

## Purpose
The network floor: one VPC across two availability zones with public and private subnets, an internet gateway, a single NAT gateway and the two route tables.

## Provisions
- `aws_vpc.main`
- `aws_subnet.public[*]`, `aws_subnet.private[*]` (count over `var.vpc.*_subnets`)
- `aws_internet_gateway.this`
- `aws_eip.this` + `aws_nat_gateway.this` (single NAT, POC trade-off)
- `aws_route_table.public` / `aws_route_table.private` with their routes and associations

## Consumes (from upstream stacks)
- none (the state bucket from 00 is referenced by name in `main.tf`)

## Provides (for downstream stacks)
- `vpc` ... consumed by 02-eks, 03-data
- `public_subnets_ids` ... consumed by 02-eks
- `private_subnets_ids` ... consumed by 02-eks, 03-data
- `internet_gateway`, `nat_gateway`, `public_subnet_arn`, `private_subnet_arn` ... published for completeness
