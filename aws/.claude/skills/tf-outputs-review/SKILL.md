---
name: tf-outputs-review
description: Review or write outputs.tf for a Terraform stack. Use when adding outputs, when refactoring outputs that downstream stacks consume, or when scaffolding a new stack's outputs.tf. Enforces whole objects for singletons, splat for plurals, snake_case names, descriptions, and documentation in the stack README.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

# Output Conventions (Pattern 10)

Outputs are the **public API** of a stack. Downstream stacks consume them via `terraform_remote_state`. Once an output is consumed, renaming it is a breaking change.

## Rules

### 1. Only Publish What Downstream Needs

Do not publish every resource ID "just in case". An empty `outputs.tf` for a leaf stack is fine. Outputs are a contract; keep the surface small.

### 2. Whole Object for Singletons

For a single resource, expose the resource object. The consumer picks the attribute it needs (`outputs.vpc.id`, `outputs.vpc.cidr_block`) without a new output per attribute.

```hcl
output "vpc" {
  description = "The VPC object. Consumed by 02-eks (cluster VPC) and 03-data (security group scope, cidr_block)."
  value       = aws_vpc.main
}

output "internet_gateway" {
  description = "The internet gateway object."
  value       = aws_internet_gateway.this
}
```

### 3. Splat for Plurals Created with `count`

```hcl
output "private_subnets_ids" {
  description = "IDs of the private subnets, in AZ order. Consumed by 02-eks (node group) and 03-data (DB subnet group)."
  value       = aws_subnet.private[*].id
}

output "private_subnet_arn" {
  description = "ARNs of the private subnets."
  value       = aws_subnet.private[*].arn
}
```

Never publish one output per index. The consumer can index into the list themselves.

### 4. Stable snake_case Names

Output names are the contract. Once a downstream stack reads `outputs.private_subnets_ids`, renaming it requires coordinating with everyone who consumes it.

- Singletons: the resource's role (`vpc`, `nat_gateway`, `eks_cluster`, `state_bucket`).
- Plurals: role + attribute suffix (`public_subnets_ids`, `private_subnet_arn`).
- A scalar convenience output is fine when a downstream needs exactly one attribute (`cluster_name` for kubeconfig, `rds_endpoint`).

### 5. Sensitive Outputs

If the output exposes a secret (password, private key, token) or a resource object that carries one, mark it sensitive:

```hcl
output "rds_instance" {
  description = "The RDS instance object (carries master_user_secret)."
  value       = aws_db_instance.this
  sensitive   = true
}
```

Better: avoid publishing the secret. Have the downstream stack read it directly from Secrets Manager.

### 6. Description on Every Output

The description says what the value is and who consumes it. It is what shows up in `terraform show` and in the audit trail. Treat it as API documentation.

### 7. Document in the Stack README

The stack's `README.md` lists what it provides (outputs) and which downstream stacks consume each one:

```markdown
## Provides (for downstream stacks)

- `vpc` ... consumed by 02-eks, 03-data
- `public_subnets_ids` ... consumed by 02-eks
- `private_subnets_ids` ... consumed by 02-eks, 03-data
- `internet_gateway`, `nat_gateway`, `public_subnet_arn`, `private_subnet_arn` ... published for completeness
```

This is the dependency map for the entire IaC project. Keep it current.

## Workflow When Reviewing

1. Read the current `outputs.tf`.
2. Read which downstream stacks consume each output (grep across the repo for `data.terraform_remote_state.<short_name>.outputs.`).
3. Flag any:
   - Missing outputs that a downstream `datasources.tf` or the README claims to consume
   - Outputs without `description`
   - Per-attribute outputs of a singleton where the whole object would do
   - Plurals not using splat
   - Sensitive values (or objects carrying them) not marked
   - Names not in snake_case
4. Propose a diff.
5. If removing an output, confirm with the user; it is a breaking change for downstream stacks.
6. Run `terraform fmt` and `terraform validate` through Bash.

## Anti-Patterns to Reject

### Per-index outputs

```hcl
# WRONG
output "subnet_0" { value = aws_subnet.private[0].id }
output "subnet_1" { value = aws_subnet.private[1].id }

# RIGHT
output "private_subnets_ids" { value = aws_subnet.private[*].id }
```

### Per-attribute outputs of a singleton

```hcl
# WRONG: three outputs, three names to keep stable
output "vpc_id"   { value = aws_vpc.main.id }
output "vpc_cidr" { value = aws_vpc.main.cidr_block }
output "vpc_arn"  { value = aws_vpc.main.arn }

# RIGHT: one object; the consumer reads outputs.vpc.id, outputs.vpc.cidr_block
output "vpc" { value = aws_vpc.main }
```

### Hand-built wrapper objects

```hcl
# WRONG: an ad-hoc map the consumer has to learn (outputs.network.subnet_ids)
output "network" {
  value = {
    vpc_id     = aws_vpc.main.id
    subnet_ids = aws_subnet.private[*].id
  }
}
```

Expose the resource object itself (`vpc`) and the splat list (`private_subnets_ids`) as two outputs. Resource objects are the provider's schema; wrapper maps are a schema nobody documents.

### Publishing internal IDs that downstream doesn't need

If only this stack consumes the value (e.g. an intermediate resource), it does not need an output. State already has it.
