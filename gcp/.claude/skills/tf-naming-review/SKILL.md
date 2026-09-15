---
name: tf-naming-review
description: Enforce Terraform resource label and tag naming conventions. Use when reviewing or writing resource blocks, when the user asks to "rename this resource" or "add tags", or when auditing a stack for naming consistency.
---

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Resource Naming and Tag Conventions

## Resource Label Convention

The label after the resource type (e.g. `aws_s3_bucket "this"`) communicates intent:

### `"this"` ... single instance

When the stack has exactly one instance of this resource type:

```hcl
resource "google_storage_bucket"  "this" { ... }
resource "google_compute_network" "this" { ... }
```

### `"main"` ... primary instance with secondaries

When there's a primary and some auxiliaries:

```hcl
resource "google_sql_database_instance" "main"    { ... }
resource "google_sql_database_instance" "replica" { ... }
```

### Role names ... multiple instances with different purposes

```hcl
resource "google_compute_firewall" "web"    { ... }
resource "google_compute_firewall" "api"    { ... }
resource "google_compute_firewall" "worker" { ... }
```

### `count` index for plurals

When provisioning N instances of the same role, use `count`:

```hcl
resource "google_compute_subnetwork" "private" {
  count = var.subnet_count
  ...
}

# referenced as google_compute_subnetwork.private[0], google_compute_subnetwork.private[*].id
```

## Label Convention (GCP)

GCP: labels replace tags. Keys and values are lowercase letters, digits, `_` and `-`, max 63 chars; keys must start with a letter. Two layers, merged in order:

### Layer 1 ... `default_labels` on the provider

Always-on labels. Set on the provider block, applied to every resource with a `labels` field.

```hcl
provider "google" {
  default_labels = {
    project    = "my-iac"
    managed_by = "terraform"
    env        = var.environment
    cost_center = var.cost_center
    owner      = var.owner
  }
}
```

### Layer 2 ... Resource-specific labels

Labels that apply only to this resource, not to all resources in the project.

```hcl
resource "google_storage_bucket" "logs" {
  name = "${var.project}-logs"
  labels = {
    purpose   = "application-logs"
    retention = "90-days"
  }
}
```

Never repeat `project`, `managed_by`, `env` here ... they come from `default_labels`.

### The `name` argument replaces the `Name` tag

Every Google Cloud resource has a `name`; it is the human-readable identifier and must match `[a-z]([-a-z0-9]*[a-z0-9])?`. Convention: `<type>-<project>-<condensed-region>` for singletons, `<type>-<project>-<condensed-region>-<index>` for plurals.

```hcl
resource "google_compute_subnetwork" "private" {
  count = 2
  name  = "private-subnet-atlas-uscentral1-${count.index + 1}"
}

# Resulting names: private-subnet-atlas-uscentral1-1, private-subnet-atlas-uscentral1-2
```

Rules for `name`:
- Lowercase, dash-separated, starts with a letter
- Condensed region (`us-central1` becomes `uscentral1`)
- No spaces, no underscores (most Compute resources reject them)

## Resources That Don't Carry `labels`

Several resources have no `labels` field (firewall rules, routers, IAM bindings, service networking connections). They cannot inherit `default_labels`; document them in the stack README instead of inventing a workaround.

Check the Google provider docs (via Context7 if uncertain) for which resource types expose `labels` (and therefore `default_labels`, `terraform_labels`, `effective_labels`).

## Workflow When Reviewing

1. Read the resource blocks in the stack.
2. Flag any:
   - Resource labels that don't follow the `this` / `main` / role convention
   - `name` values that do not follow `<type>-<project>-<condensed-region>`
   - Labels that duplicate `default_labels`
   - Missing required tags (CostCenter, Owner) if defined in `CLAUDE.md`
3. Propose a diff to fix.
4. Validate via `terraform_validate`.
5. Note: renaming a resource label triggers `terraform plan` to show destroy/create. If the resource is stateful (Cloud SQL, GCS bucket), use `moved` blocks to rename without destruction.
