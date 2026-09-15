---
name: tf-outputs-review
description: Review or write outputs.tf for a Terraform stack. Use when adding outputs, when refactoring outputs that downstream stacks consume, or when scaffolding a new stack's outputs.tf. Enforces splat for lists, stable names, and documentation in the stack README.
---

# Output Conventions

Outputs are the **public API** of a stack. Downstream stacks consume them via `terraform_remote_state`. Once an output is consumed, renaming it is a breaking change.

## Rules

### 1. Only Publish What Downstream Needs

Do not publish every resource ID "just in case". An empty `outputs.tf` for a leaf stack is fine. Outputs are a contract; keep the surface small.

### 2. Splat for Lists of Resources Created with `count` or `for_each`

```hcl
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "instance_arns" {
  value = aws_instance.worker[*].arn
}
```

Never publish one output per index. The consumer can index into the list themselves.

### 3. Stable Names

Output names are the contract. Once a downstream stack reads `outputs.vpc_id`, renaming it requires coordinating with everyone who consumes it.

Convention: `<resource_type>_<attribute>` or `<role>_<attribute>` for clarity.

```hcl
output "vpc_id"               { value = aws_vpc.this.id }
output "vpc_cidr"             { value = aws_vpc.this.cidr_block }
output "private_subnet_ids"   { value = aws_subnet.private[*].id }
output "alb_dns_name"         { value = aws_lb.web.dns_name }
output "rds_endpoint"         { value = aws_db_instance.main.endpoint }
```

### 4. Sensitive Outputs

If the output exposes a secret (password, private key, token), mark it sensitive:

```hcl
output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
```

Better: avoid publishing the secret. Have the downstream stack read it directly from Secrets Manager.

### 5. Description on Every Output

```hcl
output "private_subnet_ids" {
  description = "IDs of the private subnets across all AZs. Use for EKS node groups, RDS subnet groups, internal ALBs."
  value       = aws_subnet.private[*].id
}
```

The description is what shows up in `terraform show` and in the audit trail. Treat it as API documentation.

### 6. Document in the Stack README

The stack's `README.md` must list what it provides (outputs) and what downstream stacks consume each one. Example:

```markdown
## Provides (for downstream stacks)

- `vpc_id`             ... consumed by 02-eks, 03-rds, 04-elasticache
- `private_subnet_ids` ... consumed by 02-eks, 03-rds
- `alb_dns_name`       ... consumed by 05-dns (Route53 alias)
```

This is the dependency map for the entire IaC project. Keep it current.

## Workflow When Reviewing

1. Read the current `outputs.tf`.
2. Read which downstream stacks consume each output (grep across the repo for `data.terraform_remote_state.<this_stack>`).
3. Flag any:
   - Unused outputs (nobody consumes ... candidate for removal)
   - Missing outputs that the README claims to provide
   - Outputs without `description`
   - Lists not using splat
   - Sensitive values not marked
4. Propose a diff.
5. If removing an output, confirm with the user ... it's a breaking change for downstream stacks.
6. Validate via `terraform_validate`.

## Anti-Patterns to Reject

### Per-index outputs

```hcl
# WRONG
output "subnet_0" { value = aws_subnet.private[0].id }
output "subnet_1" { value = aws_subnet.private[1].id }
output "subnet_2" { value = aws_subnet.private[2].id }

# RIGHT
output "private_subnet_ids" { value = aws_subnet.private[*].id }
```

### Publishing internal IDs that downstream doesn't need

If only this stack consumes the value (e.g. an intermediate resource), it does not need an output. State already has it.

### Wrapping outputs in an object "for tidiness"

```hcl
# WRONG ... downstream now reads outputs.network.vpc_id (extra indirection)
output "network" {
  value = {
    vpc_id     = aws_vpc.this.id
    subnet_ids = aws_subnet.private[*].id
  }
}
```

Keep outputs flat. The consumer reads `outputs.vpc_id`, not `outputs.network.vpc_id`.
