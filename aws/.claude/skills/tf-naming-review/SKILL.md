---
name: tf-naming-review
description: Enforce Terraform resource label and tag naming conventions. Use when reviewing or writing resource blocks, when the user asks to "rename this resource" or "add tags", or when auditing a stack for naming consistency.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

# Resource Naming and Tag Conventions

Three rules, in this order: the resource label (Pattern 5), the tag block (Pattern 7), the value of the `Name` tag (Pattern 8).

## Resource Label Convention (Pattern 5)

The label after the resource type (e.g. `aws_s3_bucket "this"`) communicates intent:

### `"this"` ... single instance

When the stack has exactly one instance of this resource type:

```hcl
resource "aws_s3_bucket" "this"       { ... }
resource "aws_internet_gateway" "this" { ... }
resource "aws_eks_cluster" "this"     { ... }
```

### `"main"` ... principal resource when derivatives exist

```hcl
resource "aws_vpc" "main" { ... }     # subnets, route tables, gateways hang off it
```

### Role names ... multiple instances with different purposes

```hcl
resource "aws_subnet" "public"       { count = ... }
resource "aws_subnet" "private"      { count = ... }
resource "aws_route_table" "public"  { ... }
resource "aws_route_table" "private" { ... }
resource "aws_iam_role" "cluster"    { ... }
resource "aws_iam_role" "node"       { ... }
resource "aws_eks_access_entry" "admin" { ... }
```

Rules:
- If the resource appears once in the stack, use `this`.
- Labels are single lowercase words. No hyphens (`node`, not `eks-node-group`), no environment or project in the label.
- Plurals of the same role use `count` (Pattern 6) and are referenced as `aws_subnet.private[0]`, `aws_subnet.private[*].id`.

## Tag Block (Pattern 7)

`default_tags` on the provider injects the global tags (`Project`, `Env`, `region`, `ManagedBy`, from `var.tags`). Each resource carries ONLY the `Name` tag:

```hcl
tags = {
  Name = var.vpc.name
}
```

Inline form is fine for short resources: `tags = { Name = var.vpc.public_route_table_name }`.

- Never repeat `Project`, `Env`, `region` or `ManagedBy` on a resource.
- No second layer of resource-specific tags (`Purpose`, `Retention`, ...). If a tag is needed for cost allocation, it belongs in `var.tags`.
- Exception: tags a managed service requires for discovery (e.g. `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb` on subnets for EKS load balancers). Add them only when the platform needs them, and list each one in the stack README under Provisions.
- If a resource type does not support `tags`, say so in the stack README. Do not invent a workaround.

## Value of the `Name` Tag (Pattern 8)

Pattern: `<type>-<project>-<condensed-region>`.

```hcl
name                     = "vpc-atlas-useast1"
internet_gateway_name    = "igw-atlas-useast1"
nat_gateway_name         = "nat-gateway-atlas-useast1"
public_route_table_name  = "public-route-table-atlas-useast1"
private_route_table_name = "private-route-table-atlas-useast1"
```

- Condensed region: `us-east-1` becomes `useast1` (no hyphens).
- Plural resources take a numeric suffix: `public-subnet-1`, `public-subnet-2`, `private-subnet-1`.
- EKS cluster: `eks-cluster-<project>`; cluster IAM role: `eks-cluster-iam-role-<project>`; node group: `eks-node-group-<project>`.
- Lowercase, dash-separated, no spaces, no special characters.
- The value lives in the domain object (`var.vpc.name`), never as a literal in the resource block.

## Workflow When Reviewing

1. Read the resource blocks in the stack and the domain object in `variables.tf`.
2. Flag any:
   - Resource label that does not follow `this` / `main` / role, or contains a hyphen
   - Missing `Name` tag on a taggable resource
   - Tag other than `Name` that is not a documented discovery tag
   - Tag that duplicates `default_tags`
   - `Name` value that does not follow `<type>-<project>-<condensed-region>` (or `-<n>` for plurals)
3. Propose a diff to fix.
4. Run `terraform fmt` and `terraform validate` through Bash.
5. Note: renaming a resource label makes `terraform plan` show destroy/create. If the resource is stateful (DB, S3 bucket), use `moved` blocks to rename without destruction.
