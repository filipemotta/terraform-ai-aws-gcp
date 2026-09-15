# 01-networking

## Purpose
The network floor: a custom-mode VPC, one regional subnet with secondary ranges for GKE, Private Google Access, and Cloud Router + Cloud NAT so private nodes reach the internet.

## Provisions
- `google_compute_network.main`
- `google_compute_subnetwork.this` (primary + `pods` and `services` secondary ranges)
- `google_compute_router.this`
- `google_compute_router_nat.this`

## Consumes (from upstream stacks)
- none (the state bucket from 00 is referenced by name in `main.tf`)

## Provides (for downstream stacks)
- `network` ... consumed by 02-gke, 03-data
- `subnetwork`, `pods_range_name`, `services_range_name` ... consumed by 02-gke
- `router`, `nat` ... published for completeness

## What changed from the AWS stack (resource by resource)
| AWS (01-networking)                                  | GCP (01-networking)                                   |
|------------------------------------------------------|-------------------------------------------------------|
| `aws_vpc.main`                                       | `google_compute_network.main` (custom mode)           |
| `aws_subnet.public[2]` + `aws_subnet.private[2]`     | `google_compute_subnetwork.this` (regional, spans zones) |
| AZ placement in each subnet                          | zone placement moves to GKE `node_locations`          |
| `aws_internet_gateway.this`                          | none: the VPC has a default internet route            |
| `aws_eip.this` + `aws_nat_gateway.this`              | `google_compute_router.this` + `google_compute_router_nat.this` |
| `aws_route_table.public/private` + routes + assocs   | none: Cloud NAT applies to the subnet; no route tables to manage |
| `map_public_ip_on_launch = true` on public subnets   | none: GKE nodes are private; ingress uses load balancers |
| `Name` tag on every resource                         | `name` argument; labels come only from `default_labels` |
