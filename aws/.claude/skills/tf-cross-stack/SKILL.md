---
name: tf-cross-stack
description: Wire a downstream Terraform stack to consume outputs from an upstream stack via terraform_remote_state. Use when adding a new stack that depends on resources from a lower-numbered stack, or when refactoring a monolithic stack into separate stacks.
---

# Cross-Stack State Consumption

Numbered stacks (Pattern 1 of the architecture) communicate via `terraform_remote_state`. Stack `NN` consumes outputs of stacks `< NN`. The reverse is forbidden.

## The Pattern

### Upstream stack publishes outputs

```hcl
# terraform/01-networking/outputs.tf

output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```

### Downstream stack reads them

```hcl
# terraform/02-eks/main.tf

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "your-tf-state"
    key    = "01-networking/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_eks_cluster" "this" {
  name = "${var.environment}-cluster"

  vpc_config {
    subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  }
}
```

## Workflow When Wiring

1. **Read the upstream `outputs.tf`** first. Confirm the output you need exists and the value type matches what you expect.
   - If it does not exist, you have a decision: add the output to the upstream stack (preferred) or fetch the resource by data source from the downstream stack (acceptable when upstream is not yours).
2. **Add the `data "terraform_remote_state"` block** in the downstream stack. Use a label that describes the upstream stack (e.g. `"networking"`, `"backend"`, `"shared"`).
3. **Consume the output** as `data.terraform_remote_state.<label>.outputs.<output_name>`.
4. **Validate** via `terraform_validate`.
5. **Run `terraform plan`** to confirm the downstream stack sees the values.

## Anti-Patterns to Reject

### Hardcoding upstream values

```hcl
# WRONG
resource "aws_eks_cluster" "this" {
  vpc_config {
    subnet_ids = ["subnet-abc123", "subnet-def456"]  # ←  brittle, breaks on rebuild
  }
}
```

Drift is guaranteed. Use `terraform_remote_state`.

### Downstream stack referencing a still-higher-numbered stack

```
# WRONG ordering
01-networking/  reads from  02-eks/   # ← inverted dependency
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
3. `terraform state mv` the resources out of source into the destination stack.
4. Add the `terraform_remote_state` block in the destination stack to read what's left in the source.
5. Apply both stacks; confirm no drift.

This is risky. Take a state backup (`terraform state pull > backup.tfstate`) before starting.
