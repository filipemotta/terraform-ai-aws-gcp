---
name: tf-variables-review
description: Review or refactor Terraform input variables to follow the nested-object convention with sensible defaults. Use when the user asks to add, refactor, or review variables in a module, or when scaffolding a new stack's variables.tf.
---

# Variable Pattern Enforcement

Enforce these rules whenever you read or write `variables.tf`:

## 1. Nested Objects Over Flat Primitives

Group related inputs into one `object` variable with a `type` block. Avoid 15 flat string/number variables for related concerns.

### Bad

```hcl
variable "vpc_cidr"            { type = string }
variable "vpc_az_count"        { type = number }
variable "vpc_enable_flow_log" { type = bool }
variable "vpc_nat_per_az"      { type = bool }
```

### Good

```hcl
variable "network" {
  type = object({
    cidr            = optional(string, "10.0.0.0/16")
    az_count        = optional(number, 3)
    enable_flow_log = optional(bool, true)
    nat_per_az      = optional(bool, false)
  })
  default = {}
}
```

## 2. Defaults at the Field Level

Use `optional(type, default)` inside the type block, not `default = {...}` with every field.

This way the consumer can pass only the fields they want to override:

```hcl
module "vpc" {
  source  = "./modules/vpc"
  network = {
    cidr = "172.16.0.0/16"
    # az_count, enable_flow_log, nat_per_az use their field-level defaults
  }
}
```

## 3. Validation Blocks for Known Sets

If a field has a finite set of valid values, add a `validation` block.

```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["sandbox", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, staging, or production."
  }
}
```

## 4. Sensitive Variables

Mark secrets as `sensitive = true`:

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

## 5. Documentation

Every variable has a `description`. The description is the audit trail when a downstream engineer reads the module a year later.

```hcl
variable "network" {
  description = "VPC network configuration. cidr defaults to 10.0.0.0/16. az_count controls how many availability zones we span."
  type        = object({ ... })
  default     = {}
}
```

## Workflow When Reviewing

1. Read the current `variables.tf`.
2. Identify flat primitives that belong together (e.g. all `vpc_*` variables → `network` object).
3. Identify missing defaults, validation blocks, descriptions.
4. Propose a refactored `variables.tf` as a diff.
5. Validate via `terraform_validate` to ensure no downstream module reference broke.
6. Hand back to the parent agent for human approval.

## When NOT to Refactor

- If the module is a 3rd-party module imported via source, leave its variables alone.
- If a flat variable is the de facto public API of the module and many consumers depend on it, the breaking change might cost more than the readability gain. Document the inconsistency in the module README instead.
