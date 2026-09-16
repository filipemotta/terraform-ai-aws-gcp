---
name: tf-outputs-review
description: Review or write outputs.tf for a Terraform stack. Use when adding outputs, when refactoring outputs that downstream stacks consume, or when scaffolding a new stack's outputs.tf. Enforces whole objects for singletons, splat for plurals, snake_case names, descriptions, and documentation in the stack README.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Output Conventions (Pattern 10)

Outputs are the **public API** of a stack. Downstream stacks consume them via `terraform_remote_state`. Once an output is consumed, renaming it is a breaking change.

## Rules

### 1. Only Publish What Downstream Needs

Do not publish every resource ID "just in case". An empty `outputs.tf` for a leaf stack is fine. Outputs are a contract; keep the surface small.

### 2. Whole Object for Singletons

For a single resource, expose the resource object. The consumer picks the attribute it needs (`outputs.network.id`, `outputs.network.self_link`) without a new output per attribute.

```hcl
output "network" {
  description = "The VPC network object. Consumed by 02-gke and 03-data."
  value       = google_compute_network.main
}

output "subnetwork" {
  description = "The regional subnetwork object (id, self_link, ip_cidr_range, secondary_ip_range)."
  value       = google_compute_subnetwork.this
}
```

### 3. Splat for Plurals Created with `count`

```hcl
output "enabled_services" {
  description = "Project APIs enabled by this stack."
  value       = google_project_service.this[*].service
}
```

Never publish one output per index. The consumer can index into the list themselves.

### 4. Stable snake_case Names

Output names are the contract. Once a downstream stack reads `outputs.pods_range_name`, renaming it requires coordinating with everyone who consumes it.

- Singletons: the resource's role (`network`, `subnetwork`, `nat`, `state_bucket`).
- Plurals: role + attribute suffix (`enabled_services`, `node_service_account_emails`).
- A scalar convenience output is fine when a downstream needs exactly one attribute (`pods_range_name` for `ip_allocation_policy`, `cluster_name` for kubeconfig, `sql_connection_name`).

### 5. Sensitive Outputs

If the output exposes a secret (password, private key, token) or a resource object that carries one, mark it sensitive. GCP: `google_container_cluster` (`master_auth`) and `google_sql_database_instance` (`server_ca_cert`, root password fields) are such objects:

```hcl
output "sql_instance" {
  description = "The Cloud SQL instance object."
  value       = google_sql_database_instance.this
  sensitive   = true
}
```

Better: avoid publishing the secret. Have the downstream stack read it directly from Secret Manager.

### 6. Description on Every Output

The description says what the value is and who consumes it. It is what shows up in `terraform show` and in the audit trail. Treat it as API documentation.

### 7. Document in the Stack README

The stack's `README.md` lists what it provides (outputs) and which downstream stacks consume each one:

```markdown
## Provides (for downstream stacks)

- `network` ... consumed by 02-gke, 03-data
- `subnetwork`, `pods_range_name`, `services_range_name` ... consumed by 02-gke
- `router`, `nat` ... published for completeness
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
output "service_0" { value = google_project_service.this[0].service }
output "service_1" { value = google_project_service.this[1].service }

# RIGHT
output "enabled_services" { value = google_project_service.this[*].service }
```

### Per-attribute outputs of a singleton

```hcl
# WRONG: three outputs, three names to keep stable
output "network_id"        { value = google_compute_network.main.id }
output "network_self_link" { value = google_compute_network.main.self_link }
output "network_name"      { value = google_compute_network.main.name }

# RIGHT: one object; the consumer reads outputs.network.id, outputs.network.self_link
output "network" { value = google_compute_network.main }
```

### Hand-built wrapper objects

```hcl
# WRONG: an ad-hoc map the consumer has to learn (outputs.net.subnet_id)
output "net" {
  value = {
    network_id = google_compute_network.main.id
    subnet_id  = google_compute_subnetwork.this.id
  }
}
```

Expose the resource objects themselves (`network`, `subnetwork`) as two outputs. Resource objects are the provider's schema; wrapper maps are a schema nobody documents.

### Publishing internal IDs that downstream doesn't need

If only this stack consumes the value (e.g. an intermediate resource), it does not need an output. State already has it.
