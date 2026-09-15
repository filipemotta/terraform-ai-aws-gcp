---
name: tf-variables-review
description: Review or refactor Terraform input variables to follow the nested-object convention with complete inline defaults. Use when the user asks to add, refactor, or review variables in a stack, or when scaffolding a new stack's variables.tf.
---

> Aligned with the chapter's 13 patterns and the Act 1 corrections (see docs/pack-diff-aws-gcp.md).

# Variable Pattern Enforcement (Pattern 4)

Enforce these rules whenever you read or write `variables.tf`:

## 1. Two Variables in EVERY Stack

`tags` (the global tags the provider injects through `default_tags`) and `assume_role` (region + fallback role). Both with inline defaults, identical across stacks except for the values in `CLAUDE.md`'s bootstrap block:

```hcl
variable "tags" {
  description = "Global tags injected by the provider default_tags block. Resources only add Name."
  type        = map(string)

  default = {
    "Project"   = "atlas"
    "Env"       = "sandbox"
    "region"    = "us-east-1"
    "ManagedBy" = "terraform"
  }
}

variable "assume_role" {
  description = "Region and fallback role for the provider. role_arn is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    role_arn = string
    region   = string
  })

  default = {
    role_arn = "arn:aws:iam::123456789012:role/terraform-plan-readonly"
    region   = "us-east-1"
  }
}
```

`assume_role.role_arn` is the fallback of the `lookup()` in `main.tf`; its default is the plan-only role so that unknown workspaces (including `default`) fail closed. Never set it to the apply role.

## 2. One Nested Object per Domain

Group the stack's configuration into ONE `object` variable named after the domain (`vpc`, `eks`, `rds`). A stack that owns two domains has two objects (`03-data`: `rds` and `app_bucket`). Lists of similar resources are `list(object({...}))` inside the object. Avoid 15 flat string/number variables for related concerns.

### Bad

```hcl
variable "vpc_cidr_block"           { type = string }
variable "vpc_name"                 { type = string }
variable "public_subnet_1_cidr"     { type = string }
variable "public_subnet_2_cidr"     { type = string }
```

### Good

```hcl
variable "vpc" {
  description = "Network layout. Subnets are ordered lists consumed with count."
  type = object({
    name       = string
    cidr_block = string
    public_subnets = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool
    }))
  })

  default = {
    name       = "vpc-atlas-useast1"
    cidr_block = "10.10.0.0/16"
    public_subnets = [
      { name = "public-subnet-1", cidr_block = "10.10.0.0/24", availability_zone = "us-east-1a", map_public_ip_on_launch = true },
      { name = "public-subnet-2", cidr_block = "10.10.1.0/24", availability_zone = "us-east-1b", map_public_ip_on_launch = true },
    ]
  }
}
```

## 3. Complete Inline Defaults

Every variable carries a COMPLETE `default = {...}` directly in `variables.tf`: every field of the type is present in the default. This is the stack's configuration; reading `variables.tf` is reading what the stack builds.

- Do NOT use `optional(type, default)` inside the type block with `default = {}`. Per-field defaults hide the configuration in the type and make two places to read.
- Do NOT move the stack's default configuration into a `terraform.tfvars`. A `.tfvars` is for a per-run override, never the source of truth.
- Environment-specific overrides go through `-var-file` at plan time, if at all; the defaults stay complete.

## 4. Reference Style

- ALWAYS dot-notation on the object: `var.vpc.cidr_block`, `var.vpc.public_subnets[count.index].name`.
- NEVER flat: `var.vpc_cidr_block`, `var.public_subnet_1_name`.
- Names of resources (`Name` tag values) live in the object, not as literals in resource blocks (see `/tf-naming-review`).

## 5. POC Flags Are Explicit

Values that a production run must flip (`deletion_protection = false`, `skip_final_snapshot = true`, `multi_az = false`, `force_destroy`) sit in the object with a comment saying so, so the diff to production is visible instead of implied.

## 6. Sensitive Variables and Descriptions

- Mark secrets `sensitive = true`; better, keep them out of variables (managed passwords, Secrets Manager).
- Every variable has a `description`. It is the audit trail when an engineer reads the stack a year later.

## Workflow When Reviewing

1. Read the current `variables.tf`.
2. Confirm `tags` and `assume_role` exist with the shape above and the plan-only fallback.
3. Identify flat primitives that belong together (all `vpc_*` variables become the `vpc` object).
4. Identify `optional()` fields, `default = {}`, missing fields in a default, missing descriptions, `.tfvars` carrying defaults.
5. Propose a refactored `variables.tf` as a diff, keeping every reference in the resource files consistent (dot-notation).
6. Run `terraform fmt` and `terraform validate` through Bash to ensure no reference broke.
7. Hand back to the parent agent for human approval.

## When NOT to Refactor

- If the module is a third-party module imported via `source`, leave its variables alone.
- If a flat variable is the de facto public API of a shared module and many consumers depend on it, the breaking change might cost more than the readability gain. Document the inconsistency in the stack README instead.
