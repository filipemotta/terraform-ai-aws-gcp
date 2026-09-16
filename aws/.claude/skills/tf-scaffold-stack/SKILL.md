---
name: tf-scaffold-stack
description: Scaffold a new numbered Terraform stack following the project's architectural conventions. Use when the user asks to "create a new stack", "scaffold module X", or "add a stack for Y". Produces the directory, the main.tf/variables.tf/outputs.tf/README.md skeleton (plus datasources.tf when the stack consumes upstream state), and validates it in the default workspace.
---

> Conventions v2: the thirteen patterns plus the fixes the AWS build surfaced (see docs/gotchas-and-conventions.md).

# Scaffold a New Terraform Stack

When invoked, follow this exact sequence. Bootstrap values (`project`, `account_id`, `state_bucket`, `region_prefix`, `plan_role_arn`, `apply_role_arn`) come from the `Bootstrap Values` block in `CLAUDE.md`; the skeleton below uses the values of this repository.

## 1. Identify the Next Stack Number

List existing stacks under `terraform/` and find the highest two-digit prefix. The new stack gets the next number.

```bash
ls terraform/ | grep -E '^[0-9]{2}-' | sort
```

If the highest is `03-data`, the next is `04-<name>`.

## 2. Ask for the Stack Name (kebab-case)

Examples: `04-observability`, `05-eks-addons`, `06-dns`. Reject names with spaces, underscores, or capital letters. `<name>` without the numeric prefix is the state key (`observability/observability.tfstate`).

## 3. Create the Directory and Skeleton Files

```
NN-<name>/
├── main.tf          # terraform{} + locals (role map) + provider{} ONLY
├── variables.tf     # tags + assume_role (+ the domain object, added with the resources)
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
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "atlas-us-east-1-bucket-terraform-state"
    key          = "<name>/<name>.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Workspace-aware role selection: production is plan-only for the agent.
# The hard guardrail lives in IAM (see iam/README.md), not here.
# Any workspace not listed here (including "default", the one a fresh
# `terraform init` lands in) falls back to var.assume_role.role_arn, which
# defaults to the plan-only role: unknown workspaces fail closed.
locals {
  workspace_role_arn = {
    sandbox    = "arn:aws:iam::123456789012:role/terraform-apply"
    staging    = "arn:aws:iam::123456789012:role/terraform-apply"
    production = "arn:aws:iam::123456789012:role/terraform-plan-readonly"
  }
}

provider "aws" {
  region = var.assume_role.region

  default_tags {
    tags = var.tags
  }

  assume_role {
    role_arn = lookup(local.workspace_role_arn, terraform.workspace, var.assume_role.role_arn)
  }
}
```

### `variables.tf`

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

The domain object variable (`variable "<domain>"` with a complete inline `default = {...}`) is added together with the first resource file, following `/tf-variables-review`.

### `outputs.tf`

Empty initially. Add outputs only as downstream stacks need them (`/tf-outputs-review`).

### `datasources.tf` (only when consuming upstream state)

```hcl
# Named workspaces (sandbox/staging/production) store state under
# env:/<workspace>/<key>; without `workspace` this block would silently read
# the default workspace's state, which does not exist in this layout.
data "terraform_remote_state" "network" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket = "atlas-us-east-1-bucket-terraform-state"
    key    = "networking/networking.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.network.outputs.vpc.id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids
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
- Reminder that the bootstrap values in `main.tf` and `variables.tf` (`123456789012`, the bucket name, the two role ARNs) must match `CLAUDE.md`

The parent agent or `@terraform-architect` continues with the domain object and the resource files.
