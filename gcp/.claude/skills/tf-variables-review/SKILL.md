---
name: tf-variables-review
description: Review or refactor Terraform input variables to follow the nested-object convention with complete inline defaults. Use when the user asks to add, refactor, or review variables in a stack, or when scaffolding a new stack's variables.tf.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Variable Pattern Enforcement (Pattern 4)

Enforce these rules whenever you read or write `variables.tf`:

## 1. Two Variables in EVERY Stack

GCP: `labels` (the global labels the provider injects through `default_labels`) and `impersonation` (project, region + fallback service account). Both with inline defaults, identical across stacks except for the values in `CLAUDE.md`'s bootstrap block:

```hcl
variable "labels" {
  description = "Global labels injected by the provider default_labels argument. Resources add nothing else; their identity is the name argument."
  type        = map(string)

  default = {
    "project"    = "atlas"
    "env"        = "sandbox"
    "region"     = "us-central1"
    "managed_by" = "terraform"
  }
}

variable "impersonation" {
  description = "Project, region and fallback service account for the provider. service_account is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    project_id      = string
    region          = string
    service_account = string
  })

  default = {
    project_id      = "atlas-demo-123"
    region          = "us-central1"
    service_account = "terraform-plan@atlas-demo-123.iam.gserviceaccount.com"
  }
}
```

`impersonation.service_account` is the fallback of the `lookup()` in `main.tf`; its default is the plan-only account so that unknown workspaces (including `default`) fail closed. Never set it to the apply account.

## 2. One Nested Object per Domain

Group the stack's configuration into ONE `object` variable named after the domain (`vpc`, `gke`, `sql`). A stack that owns two domains has two objects (`03-data`: `sql` and `app_bucket`; `00-remote-backend`: `remote_backend` and `project`). Lists of similar resources are `list(object({...}))` inside the object. Avoid 15 flat string/number variables for related concerns.

### Bad

```hcl
variable "vpc_name"                 { type = string }
variable "subnet_ip_cidr_range"     { type = string }
variable "pods_range_cidr"          { type = string }
variable "services_range_cidr"      { type = string }
```

### Good

```hcl
variable "vpc" {
  description = "Network layout. One regional subnet with secondary ranges for GKE."
  type = object({
    name         = string
    routing_mode = string
    subnetwork = object({
      name          = string
      ip_cidr_range = string
      secondary_ip_ranges = list(object({
        range_name    = string
        ip_cidr_range = string
      }))
    })
  })

  default = {
    name         = "vpc-atlas-uscentral1"
    routing_mode = "REGIONAL"
    subnetwork = {
      name          = "subnet-atlas-uscentral1"
      ip_cidr_range = "10.20.0.0/20"
      secondary_ip_ranges = [
        { range_name = "pods", ip_cidr_range = "10.21.0.0/16" },
        { range_name = "services", ip_cidr_range = "10.22.0.0/20" },
      ]
    }
  }
}
```

## 3. Complete Inline Defaults

Every variable carries a COMPLETE `default = {...}` directly in `variables.tf`: every field of the type is present in the default. This is the stack's configuration; reading `variables.tf` is reading what the stack builds.

- Do NOT use `optional(type, default)` inside the type block with `default = {}`. Per-field defaults hide the configuration in the type and make two places to read.
- Do NOT move the stack's default configuration into a `terraform.tfvars`. A `.tfvars` is for a per-run override, never the source of truth.
- Environment-specific overrides go through `-var-file` at plan time, if at all; the defaults stay complete.

## 4. Reference Style

- ALWAYS dot-notation on the object: `var.vpc.subnetwork.ip_cidr_range`, `var.gke.node_service_account_roles[count.index]`.
- NEVER flat: `var.vpc_name`, `var.subnet_ip_cidr_range`.
- Names of resources (`name` argument values) live in the object, not as literals in resource blocks (see `/tf-naming-review`).

## 5. POC Flags Are Explicit

Values that a production run must flip (`deletion_protection = false`, `availability_type = "ZONAL"`, `force_destroy`, `disable_on_destroy`) sit in the object with a comment saying so, so the diff to production is visible instead of implied. GCP: values the API derives silently (Cloud SQL `edition`, which `POSTGRES_16+` defaults to `ENTERPRISE_PLUS` and rejects shared-core tiers) are written out with the reason in a comment.

## 6. Sensitive Variables and Descriptions

- Mark secrets `sensitive = true`; better, keep them out of variables (IAM database authentication, Secret Manager).
- Every variable has a `description`. It is the audit trail when an engineer reads the stack a year later.

## Workflow When Reviewing

1. Read the current `variables.tf`.
2. Confirm `labels` and `impersonation` exist with the shape above and the plan-only fallback.
3. Identify flat primitives that belong together (all `vpc_*` variables become the `vpc` object).
4. Identify `optional()` fields, `default = {}`, missing fields in a default, missing descriptions, `.tfvars` carrying defaults.
5. Propose a refactored `variables.tf` as a diff, keeping every reference in the resource files consistent (dot-notation).
6. Run `terraform fmt` and `terraform validate` through Bash to ensure no reference broke.
7. Hand back to the parent agent for human approval.

## When NOT to Refactor

- If the module is a third-party module imported via `source`, leave its variables alone.
- If a flat variable is the de facto public API of a shared module and many consumers depend on it, the breaking change might cost more than the readability gain. Document the inconsistency in the stack README instead.
