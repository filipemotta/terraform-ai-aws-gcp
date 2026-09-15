---
name: tf-cross-stack
description: Wire a downstream Terraform stack to consume outputs from an upstream stack via terraform_remote_state. Use when adding a new stack that depends on resources from a lower-numbered stack, or when refactoring a monolithic stack into separate stacks.
---

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Cross-Stack State Consumption

Numbered stacks (Pattern 1 of the architecture) communicate via `terraform_remote_state`. Stack `NN` consumes outputs of stacks `< NN`. The reverse is forbidden.

## The Pattern

### Upstream stack publishes outputs

```hcl
# terraform/01-networking/outputs.tf

output "network_id" {
  value = google_compute_network.main.id
}

output "subnetwork_id" {
  value = google_compute_subnetwork.this.id
}

output "pods_range_name" {
  value = google_compute_subnetwork.this.secondary_ip_range[0].range_name
}
```

### Downstream stack reads them

```hcl
# terraform/02-gke/datasources.tf

data "terraform_remote_state" "networking" {
  backend   = "gcs"
  workspace = terraform.workspace
  config = {
    bucket = "your-tf-state"
    prefix = "networking"
  }
}

resource "google_container_cluster" "this" {
  name       = "${var.environment}-cluster"
  network    = data.terraform_remote_state.networking.outputs.network_id
  subnetwork = data.terraform_remote_state.networking.outputs.subnetwork_id
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
resource "google_container_cluster" "this" {
  subnetwork = "projects/atlas-demo-123/regions/us-central1/subnetworks/subnet-abc"  # ←  brittle, breaks on rebuild
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

1. A service account they let you impersonate with `roles/storage.objectViewer` on their state bucket, or
2. Data sources against the actual Google Cloud resources (`data "google_compute_network"`, `data "google_compute_subnetwork"`).

Document the dependency in your stack's README.

## Migration: Splitting a Monolithic Stack

When refactoring one fat stack into two:

1. Add `outputs.tf` to the source stack publishing everything the destination will need.
2. Apply the source stack to bake the outputs into state.
3. `terraform state mv` the resources out of source into the destination stack.
4. Add the `terraform_remote_state` block in the destination stack to read what's left in the source.
5. Apply both stacks; confirm no drift.

This is risky. Take a state backup (`terraform state pull > backup.tfstate`) before starting.
