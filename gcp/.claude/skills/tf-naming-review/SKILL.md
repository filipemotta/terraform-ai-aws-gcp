---
name: tf-naming-review
description: Enforce Terraform resource label and label/name naming conventions. Use when reviewing or writing resource blocks, when the user asks to "rename this resource" or "add labels", or when auditing a stack for naming consistency.
---

> Aligned with the chapter's 13 patterns and the Act 1 corrections (see docs/pack-diff-aws-gcp.md).

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Resource Naming and Label Conventions

Three rules, in this order: the resource label (Pattern 5), the labels block (Pattern 7), the value of the `name` argument (Pattern 8).

## Resource Label Convention (Pattern 5)

The label after the resource type (e.g. `google_storage_bucket "this"`) communicates intent:

### `"this"` ... single instance

When the stack has exactly one instance of this resource type:

```hcl
resource "google_storage_bucket" "this"     { ... }
resource "google_compute_subnetwork" "this" { ... }
resource "google_container_cluster" "this"  { ... }
```

### `"main"` ... principal resource when derivatives exist

```hcl
resource "google_compute_network" "main" { ... }     # subnetwork, router, NAT hang off it
```

### Role names ... multiple instances with different purposes

```hcl
resource "google_service_account" "node"     { ... }
resource "google_service_account" "app"      { ... }
resource "google_project_iam_member" "node"  { count = ... }
resource "google_project_iam_member" "app"   { ... }
```

Rules:
- If the resource appears once in the stack, use `this`.
- Labels are single lowercase words. No hyphens (`node`, not `gke-node-pool`), no environment or project in the label.
- Plurals of the same role use `count` (Pattern 6) and are referenced as `google_project_iam_member.node[0]`, `google_project_service.this[*].service`.

## Labels Block (Pattern 7)

GCP: `default_labels` on the provider injects the global labels (`project`, `env`, `region`, `managed_by`, from `var.labels`) on every resource that has a `labels` field. Resources carry NO `labels` block of their own; their identity is the `name` argument:

```hcl
resource "google_compute_network" "main" {
  name                    = var.vpc.name
  auto_create_subnetworks = false
  routing_mode            = var.vpc.routing_mode
}
```

- Never repeat `project`, `env`, `region` or `managed_by` on a resource.
- No second layer of resource-specific labels (`purpose`, `retention`, ...). If a label is needed for cost allocation, it belongs in `var.labels`.
- Exception: labels a managed service requires (for discovery, billing export or a feature that keys on a label). Add them only when the platform needs them, and list each one in the stack README under Provisions.
- GCP: resources without a `labels` field (firewall rules, routers, IAM bindings, service networking connections) cannot inherit `default_labels`; say so in the stack README. Do not invent a workaround.
- GCP: label keys and values are lowercase letters, digits, `_` and `-`, max 63 characters; keys start with a letter.

## Value of the `name` Argument (Pattern 8)

Pattern: `<type>-<project>-<condensed-region>`.

```hcl
name        = "vpc-atlas-uscentral1"
router_name = "router-atlas-uscentral1"
nat_name    = "nat-atlas-uscentral1"
subnetwork = {
  name = "subnet-atlas-uscentral1"
}
instance_name = "sql-postgres-atlas-uscentral1"
```

- Condensed region: `us-central1` becomes `uscentral1` (no hyphens).
- Plural resources take a numeric suffix: `subnet-atlas-uscentral1-1`, `subnet-atlas-uscentral1-2`.
- GKE cluster: `gke-cluster-<project>`; node pool: `gke-node-pool-<project>`; node service account id: `gke-node-<project>`.
- GCP: lowercase, dash-separated, starts with a letter, no underscores; most resource names must match `[a-z]([-a-z0-9]*[a-z0-9])?`, and service account ids are 6 to 30 characters.
- The value lives in the domain object (`var.vpc.name`), never as a literal in the resource block.

## Workflow When Reviewing

1. Read the resource blocks in the stack and the domain object in `variables.tf`.
2. Flag any:
   - Resource label that does not follow `this` / `main` / role, or contains a hyphen
   - `labels` block on a resource that is not a documented service label
   - Label that duplicates `default_labels`
   - `name` value that does not follow `<type>-<project>-<condensed-region>` (or `-<n>` for plurals), or that GCP's name regex rejects
   - Resource without a `labels` field that the README does not mention
3. Propose a diff to fix.
4. Run `terraform fmt` and `terraform validate` through Bash.
5. Note: renaming a resource label makes `terraform plan` show destroy/create. If the resource is stateful (Cloud SQL, GCS bucket), use `moved` blocks to rename without destruction.
