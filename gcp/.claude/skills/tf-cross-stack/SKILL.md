---
name: tf-cross-stack
description: Wire a downstream Terraform stack to consume outputs from an upstream stack via terraform_remote_state. Use when adding a new stack that depends on resources from a lower-numbered stack, or when splitting one oversized stack into separate stacks.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Cross-Stack State Consumption (Pattern 11)

Numbered stacks (Pattern 1) communicate via `terraform_remote_state`. Stack `NN` consumes outputs of stacks `< NN`. The reverse is forbidden.

## The Pattern

### Upstream stack publishes outputs (whole objects, splat for plurals)

```hcl
# terraform/01-networking/outputs.tf

output "network" {
  description = "The VPC network object. Consumed by 02-gke and 03-data."
  value       = google_compute_network.main
}

output "subnetwork" {
  description = "The regional subnetwork object (id, self_link, ip_cidr_range, secondary_ip_range)."
  value       = google_compute_subnetwork.this
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods. Consumed by 02-gke ip_allocation_policy."
  value       = google_compute_subnetwork.this.secondary_ip_range[0].range_name
}
```

### Downstream stack reads them in `datasources.tf`, normalises in `locals`

```hcl
# terraform/02-gke/datasources.tf

# Named workspaces (sandbox/staging/production) store state as
# <prefix>/<workspace>.tfstate; without `workspace` this block would silently
# read the default workspace's state, which does not exist in this layout.
data "terraform_remote_state" "network" {
  backend   = "gcs"
  workspace = terraform.workspace

  config = {
    bucket = "atlas-us-central1-bucket-terraform-state"
    prefix = "networking"
  }
}

locals {
  network_id          = data.terraform_remote_state.network.outputs.network.id
  subnetwork_id       = data.terraform_remote_state.network.outputs.subnetwork.id
  pods_range_name     = data.terraform_remote_state.network.outputs.pods_range_name
  services_range_name = data.terraform_remote_state.network.outputs.services_range_name
}
```

```hcl
# terraform/02-gke/gke-cluster.tf

resource "google_container_cluster" "this" {
  name       = var.gke.cluster_name
  network    = local.network_id
  subnetwork = local.subnetwork_id

  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_range_name
    services_secondary_range_name = local.services_range_name
  }
}
```

Rules:
- The block lives in `datasources.tf` (Pattern 9), never in `main.tf` or next to resources.
- `workspace = terraform.workspace` is mandatory. GCP: the GCS backend stores named workspaces at `<prefix>/<workspace>.tfstate`; without the argument the data source reads `<prefix>/default.tfstate`, which this layout never writes, and the plan fails with a missing output in a stack that validated clean.
- GCP: `config = { bucket, prefix }`; `prefix` is the upstream stack's backend prefix (`networking`).
- Data source name is the short stack name (`network`, not `networking_state`).
- Resources consume `local.<name>`, never `data.terraform_remote_state...` directly.

## Workflow When Wiring

1. **Read the upstream `outputs.tf`** first. Confirm the output you need exists and its shape (whole object or list) matches what you expect.
   - If it does not exist, you have a decision: add the output to the upstream stack (preferred) or fetch the resource by data source from the downstream stack (acceptable when upstream is not yours).
2. **Add the `data "terraform_remote_state"` block** to `datasources.tf` with `workspace = terraform.workspace` and the upstream prefix.
3. **Normalise in `locals`** (`local.network_id`, `local.subnetwork_id`).
4. **Consume the locals** in the resource files.
5. **Validate**: `terraform init -backend=false && terraform validate` through Bash.
6. **Run `terraform plan`** (with credentials and a selected workspace) to confirm the downstream stack sees the values. Validate cannot check that the upstream state exists.

## Anti-Patterns to Reject

### Hardcoding upstream values

```hcl
# WRONG
resource "google_container_cluster" "this" {
  subnetwork = "projects/atlas-demo-123/regions/us-central1/subnetworks/subnet-abc"  # brittle, breaks on rebuild
}
```

Drift is guaranteed. Use `terraform_remote_state`.

### Remote state without `workspace`

```hcl
# WRONG: reads networking/default.tfstate, which no stack in this layout writes
data "terraform_remote_state" "network" {
  backend = "gcs"
  config  = { bucket = "...", prefix = "networking" }
}
```

### Downstream stack referencing a still-higher-numbered stack

```
# WRONG ordering
01-networking/  reads from  02-gke/   # inverted dependency
```

If you find yourself wanting this, you have a stack-numbering mistake. Re-design.

### Sharing state files

Never put two stacks' resources into the same `tfstate`. The whole point of stack numbering is state isolation.

## When the Upstream Stack Is External

If the upstream stack is not in your repo (e.g. a shared platform stack owned by another team), prefer:

1. A service account they let you impersonate with `roles/storage.objectViewer` on their state bucket, or
2. Data sources against the actual Google Cloud resources (`data "google_compute_network"`, `data "google_compute_subnetwork"`).

Document the dependency in your stack's README.

## Migration: Splitting an Oversized Stack

When refactoring one fat stack into two:

1. Add `outputs.tf` to the source stack publishing everything the destination will need.
2. Apply the source stack to bake the outputs into state.
3. `terraform state mv` the resources out of source into the destination stack (a human runs it; the hook blocks state moves on production).
4. Add the `terraform_remote_state` block in the destination stack to read what's left in the source.
5. Apply both stacks; confirm no drift.

This is risky. Take a state backup (`terraform state pull > backup.tfstate`) before starting.
