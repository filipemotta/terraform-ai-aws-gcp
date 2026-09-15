---
name: tf-scaffold-stack
description: Scaffold a new numbered Terraform stack following the project's architectural conventions. Use when the user asks to "create a new stack", "scaffold module X", or "add a stack for Y". Produces the directory, provider/backend/variables/outputs/README skeleton, and validates the initial state.
---

# Scaffold a New Terraform Stack

When invoked, follow this exact sequence:

## 1. Identify the Next Stack Number

List existing stacks under `terraform/` and find the highest two-digit prefix. The new stack gets the next number.

```bash
ls terraform/ | grep -E '^[0-9]{2}-' | sort
```

If the highest is `02-eks`, the next is `03-<name>`.

## 2. Ask for the Stack Name (kebab-case)

Examples: `03-rds`, `04-eks-addons`, `05-monitoring`. Reject names with spaces, underscores, or capital letters.

## 3. Create the Directory and Skeleton Files

```
NN-<name>/
├── provider.tf
├── backend.tf
├── variables.tf
├── outputs.tf
├── main.tf
└── README.md
```

### `provider.tf`

```hcl
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = var.tags }

  assume_role {
    role_arn = local.workspace_role_arn[terraform.workspace]
  }
}

locals {
  workspace_role_arn = {
    sandbox    = "arn:aws:iam::ACCOUNT:role/terraform-apply"
    staging    = "arn:aws:iam::ACCOUNT:role/terraform-apply"
    production = "arn:aws:iam::ACCOUNT:role/terraform-plan-readonly"
  }
}
```

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket       = "your-tf-state"
    key          = "NN-<name>/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `variables.tf`

```hcl
variable "region" { type = string }
variable "tags"   { type = map(string), default = {} }
```

### `outputs.tf`

Empty initially. Add outputs only as downstream stacks need them.

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

## 4. Initialize and Validate

```bash
cd terraform/NN-<name>
terraform init
terraform validate
```

If validate fails, surface the error and stop. Do not write business resources until the skeleton validates.

## 5. Hand Off

Hand back to the parent agent with:
- The stack created (path)
- Init + validate output
- Reminder that `backend.tf` placeholder values (`your-tf-state`, `ACCOUNT`) must be replaced with the project's actual bootstrap values from `CLAUDE.md`

The parent agent or `@terraform-architect` continues with the actual business resources.
