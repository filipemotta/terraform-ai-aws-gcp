---
name: tf-cross-stack
description: Wire a downstream Terraform stack to consume outputs from an upstream stack via terraform_remote_state. Use when adding a new stack that depends on resources from a lower-numbered stack, or when refactoring a monolithic stack into separate stacks.
---

> Aligned with the chapter's 13 patterns and the Act 1 corrections (see docs/pack-diff-aws-gcp.md).

# Cross-Stack State Consumption (Pattern 11)

Numbered stacks (Pattern 1) communicate via `terraform_remote_state`. Stack `NN` consumes outputs of stacks `< NN`. The reverse is forbidden.

## The Pattern

### Upstream stack publishes outputs (whole objects, splat for plurals)

```hcl
# terraform/01-networking/outputs.tf

output "vpc" {
  description = "The VPC object. Consumed by 02-eks and 03-data."
  value       = aws_vpc.main
}

output "private_subnets_ids" {
  description = "IDs of the private subnets, in AZ order. Consumed by 02-eks and 03-data."
  value       = aws_subnet.private[*].id
}

output "public_subnets_ids" {
  description = "IDs of the public subnets, in AZ order. Consumed by 02-eks."
  value       = aws_subnet.public[*].id
}
```

### Downstream stack reads them in `datasources.tf`, normalises in `locals`

```hcl
# terraform/02-eks/datasources.tf

# Named workspaces (sandbox/staging/production) store state under
# env:/<workspace>/<key>; without `workspace` this block would silently read
# the default workspace's state, which does not exist in this layout.
data "terraform_remote_state" "network" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket = "atlas-us-east-1-bucket-terraform-state"
    key    = "networking/networking.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.network.outputs.vpc.id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnets_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids
}
```

```hcl
# terraform/02-eks/eks-cluster.tf

resource "aws_eks_cluster" "this" {
  name     = var.eks.cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = local.private_subnet_ids
  }
}
```

Rules:
- The block lives in `datasources.tf` (Pattern 9), never in `main.tf` or next to resources.
- `workspace = terraform.workspace` is mandatory. The S3 backend stores named workspaces at `env:/<workspace>/<key>`; without the argument the data source reads the `default` workspace's state, which this layout never writes, and the plan fails with a missing output in a stack that validated clean.
- `key` follows the upstream stack's backend key: `<stack>/<stack>.tfstate`.
- Data source name is the short stack name (`network`, not `networking_state`).
- Resources consume `local.<name>`, never `data.terraform_remote_state...` directly.

## Workflow When Wiring

1. **Read the upstream `outputs.tf`** first. Confirm the output you need exists and its shape (whole object or list) matches what you expect.
   - If it does not exist, you have a decision: add the output to the upstream stack (preferred) or fetch the resource by data source from the downstream stack (acceptable when upstream is not yours).
2. **Add the `data "terraform_remote_state"` block** to `datasources.tf` with `workspace = terraform.workspace` and the upstream key.
3. **Normalise in `locals`** (`local.vpc_id`, `local.private_subnet_ids`).
4. **Consume the locals** in the resource files.
5. **Validate**: `terraform init -backend=false && terraform validate` through Bash.
6. **Run `terraform plan`** (with credentials and a selected workspace) to confirm the downstream stack sees the values. Validate cannot check that the upstream state exists.

## Anti-Patterns to Reject

### Hardcoding upstream values

```hcl
# WRONG
resource "aws_eks_cluster" "this" {
  vpc_config {
    subnet_ids = ["subnet-abc123", "subnet-def456"]  # brittle, breaks on rebuild
  }
}
```

Drift is guaranteed. Use `terraform_remote_state`.

### Remote state without `workspace`

```hcl
# WRONG: reads env "default", which no stack in this layout writes
data "terraform_remote_state" "network" {
  backend = "s3"
  config  = { bucket = "...", key = "networking/networking.tfstate", region = "us-east-1" }
}
```

### Downstream stack referencing a still-higher-numbered stack

```
# WRONG ordering
01-networking/  reads from  02-eks/   # inverted dependency
```

If you find yourself wanting this, you have a stack-numbering mistake. Re-design.

### Sharing state files

Never put two stacks' resources into the same `tfstate`. The whole point of stack numbering is state isolation.

## When the Upstream Stack Is External

If the upstream stack is not in your repo (e.g. a shared platform stack owned by another team), prefer:

1. A read-only IAM role they grant you to read their state bucket, or
2. Data sources against the actual AWS resources (`data "aws_vpc"`, `data "aws_subnets"`) with filters on tags.

Document the dependency in your stack's README.

## Migration: Splitting a Monolithic Stack

When refactoring one fat stack into two:

1. Add `outputs.tf` to the source stack publishing everything the destination will need.
2. Apply the source stack to bake the outputs into state.
3. `terraform state mv` the resources out of source into the destination stack (a human runs it; the hook blocks state moves on production).
4. Add the `terraform_remote_state` block in the destination stack to read what's left in the source.
5. Apply both stacks; confirm no drift.

This is risky. Take a state backup (`terraform state pull > backup.tfstate`) before starting.
