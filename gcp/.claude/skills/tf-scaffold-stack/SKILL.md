---
name: tf-scaffold-stack
description: Scaffold a new numbered Terraform stack following the project's architectural conventions. Use when the user asks to "create a new stack", "scaffold module X", or "add a stack for Y". Produces the directory, the main.tf/variables.tf/outputs.tf/README.md skeleton (plus datasources.tf when the stack consumes upstream state), and validates it in the default workspace.
---

> Aligned with the chapter's 13 patterns and the Act 1 corrections (see docs/pack-diff-aws-gcp.md).

> **GCP flavor.** Same pack, same 13 patterns. Only the cloud-specific lines changed; each is marked `GCP:` inline. Diff against `../aws/` to see exactly what moved.

# Scaffold a New Terraform Stack

When invoked, follow this exact sequence. Bootstrap values (`project`, `project_id`, `state_bucket`, `region_prefix`, `plan_sa`, `apply_sa`) come from the `Bootstrap Values` block in `CLAUDE.md`; the skeleton below uses the values of this repository.

## 1. Identify the Next Stack Number

List existing stacks under `terraform/` and find the highest two-digit prefix. The new stack gets the next number.

```bash
ls terraform/ | grep -E '^[0-9]{2}-' | sort
```

If the highest is `03-data`, the next is `04-<name>`.

## 2. Ask for the Stack Name (kebab-case)

Examples: `04-observability`, `05-gke-addons`, `06-dns`. Reject names with spaces, underscores, or capital letters. GCP: `<name>` without the numeric prefix is the backend `prefix` (`observability`; the object becomes `observability/<workspace>.tfstate`).

## 3. Create the Directory and Skeleton Files

```
NN-<name>/
├── main.tf          # terraform{} + locals (service account map) + provider{} ONLY
├── variables.tf     # labels + impersonation (+ the domain object, added with the resources)
├── outputs.tf       # empty until a downstream stack needs something
├── datasources.tf   # only if the stack consumes upstream state (see /tf-cross-stack)
└── README.md
```

No `provider.tf`, no `backend.tf`: the backend and the provider live in `main.tf` (Pattern 9). Resources never go in `main.tf`; they get one kebab-case file per resource group.

### `main.tf`

```hcl
# Stack NN-<name>: <one sentence>.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # GCS locks natively and encrypts at rest by default: no lock table, no
  # `encrypt`/`use_lockfile` switches. The state object is
  # <prefix>/<workspace>.tfstate, so the workspace name, not the stack name,
  # ends the path. Backend access uses the ambient credentials (ADC) or
  # GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT; see iam/plan-only-role.md.
  backend "gcs" {
    bucket = "atlas-us-central1-bucket-terraform-state"
    prefix = "<name>"
  }
}

# Workspace-aware identity selection: production is plan-only for the agent.
# The hard guardrail lives in IAM (see iam/plan-only-role.md), not here.
# Any workspace not listed here (including "default", the one a fresh
# `terraform init` lands in) falls back to var.impersonation.service_account,
# which defaults to the plan-only account: unknown workspaces fail closed.
locals {
  workspace_service_account = {
    sandbox    = "terraform-apply@atlas-demo-123.iam.gserviceaccount.com"
    staging    = "terraform-apply@atlas-demo-123.iam.gserviceaccount.com"
    production = "terraform-plan@atlas-demo-123.iam.gserviceaccount.com"
  }
}

provider "google" {
  project        = var.impersonation.project_id
  region         = var.impersonation.region
  default_labels = var.labels

  impersonate_service_account = lookup(local.workspace_service_account, terraform.workspace, var.impersonation.service_account)
}
```

### `variables.tf`

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

The domain object variable (`variable "<domain>"` with a complete inline `default = {...}`) is added together with the first resource file, following `/tf-variables-review`.

### `outputs.tf`

Empty initially. Add outputs only as downstream stacks need them (`/tf-outputs-review`).

### `datasources.tf` (only when consuming upstream state)

```hcl
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
  network_id    = data.terraform_remote_state.network.outputs.network.id
  subnetwork_id = data.terraform_remote_state.network.outputs.subnetwork.id
}
```

### `README.md`

```markdown
# NN-<name>

## Purpose
<one sentence>

## Provisions
- (list resources)

## Consumes (from upstream stacks)
- (list which remote_state outputs are read)

## Provides (for downstream stacks)
- (list outputs published)

## What changed from the AWS stack (resource by resource)
| AWS (NN-<name>) | GCP (NN-<name>) |
|---|---|
| (when an AWS twin exists: one row per resource, or "none" when the concept has no counterpart) | |
```

## 4. Format and Validate (offline, default workspace)

```bash
cd terraform/NN-<name>
terraform fmt -check
terraform init -backend=false -input=false
terraform validate
```

`-backend=false` keeps the skeleton validation free of credentials and of the state bucket. The skeleton must validate in the `default` workspace, which is where a fresh checkout is; that is what the `lookup()` fallback in `main.tf` guarantees. A plain `terraform init` (with the backend) comes later, when credentials exist and a workspace is selected.

If validate fails, surface the error and stop. Do not write business resources until the skeleton validates.

## 5. Hand Off

Hand back to the parent agent with:
- The stack created (path)
- fmt + init + validate output
- Reminder that the bootstrap values in `main.tf` and `variables.tf` (`atlas-demo-123`, the bucket name, the two service account emails) must match `CLAUDE.md`

The parent agent or `@terraform-architect` continues with the domain object and the resource files.
