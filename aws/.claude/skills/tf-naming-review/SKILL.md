---
name: tf-naming-review
description: Enforce Terraform resource label and tag naming conventions. Use when reviewing or writing resource blocks, when the user asks to "rename this resource" or "add tags", or when auditing a stack for naming consistency.
---

# Resource Naming and Tag Conventions

## Resource Label Convention

The label after the resource type (e.g. `aws_s3_bucket "this"`) communicates intent:

### `"this"` ... single instance

When the stack has exactly one instance of this resource type:

```hcl
resource "aws_s3_bucket" "this" { ... }
resource "aws_vpc"        "this" { ... }
```

### `"main"` ... primary instance with secondaries

When there's a primary and some auxiliaries:

```hcl
resource "aws_db_instance" "main"    { ... }
resource "aws_db_instance" "replica" { ... }
```

### Role names ... multiple instances with different purposes

```hcl
resource "aws_security_group" "web"    { ... }
resource "aws_security_group" "api"    { ... }
resource "aws_security_group" "worker" { ... }
```

### `count` index for plurals

When provisioning N instances of the same role, use `count`:

```hcl
resource "aws_subnet" "private" {
  count = var.az_count
  ...
}

# referenced as aws_subnet.private[0], aws_subnet.private[*].id
```

## Tag Convention

Three layers of tags, merged in order:

### Layer 1 ... `default_tags` on the provider

Always-on tags. Set on the provider block, inherited by all resources that support tagging.

```hcl
provider "aws" {
  default_tags {
    tags = {
      Project     = "my-iac"
      ManagedBy   = "terraform"
      Environment = var.environment
      CostCenter  = var.cost_center
      Owner       = var.owner
    }
  }
}
```

### Layer 2 ... Resource-specific tags

Tags that apply only to this resource, not to all resources in the project.

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-logs"
  tags = {
    Purpose      = "Application logs"
    Retention    = "90-days"
  }
}
```

Never repeat `Project`, `ManagedBy`, `Environment` here ... they come from `default_tags`.

### Layer 3 ... `Name` tag

The `Name` tag is the human-readable identifier. Convention: `<env>-<role>-<index>`.

```hcl
resource "aws_instance" "web" {
  count = 3
  tags = {
    Name = "${var.environment}-web-${format("%02d", count.index + 1)}"
  }
}

# Resulting names: prod-web-01, prod-web-02, prod-web-03
```

Rules for the `Name` tag:
- Lowercase, dash-separated
- No environment ambiguity (always include `<env>`)
- Numbers padded to 2 digits if there will be more than 9 instances
- No spaces, no special characters

## Resources That Don't Inherit `default_tags`

Some resources do not inherit `default_tags` from the provider (notably `aws_s3_object`, some EBS attachments). For these, set tags manually using the same merge pattern:

```hcl
resource "aws_s3_object" "data" {
  ...
  tags = merge(
    {
      Project     = "my-iac"
      ManagedBy   = "terraform"
      Environment = var.environment
    },
    {
      Purpose = "data export"
    }
  )
}
```

Check the AWS provider docs (via Context7 if uncertain) for which resource types support `default_tags` propagation.

## Workflow When Reviewing

1. Read the resource blocks in the stack.
2. Flag any:
   - Resource labels that don't follow the `this` / `main` / role convention
   - Missing `Name` tag where appropriate
   - Tags that duplicate `default_tags`
   - Missing required tags (CostCenter, Owner) if defined in `CLAUDE.md`
3. Propose a diff to fix.
4. Validate via `terraform_validate`.
5. Note: renaming a resource label triggers `terraform plan` to show destroy/create. If the resource is stateful (DB, S3 bucket), use `moved` blocks to rename without destruction.
