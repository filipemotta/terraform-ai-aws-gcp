# Stack 02-eks: EKS control plane, one small managed node group (Graviton),
# the two IAM roles and an explicit admin access entry. Network comes from 01.

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
    key          = "eks/eks.tfstate"
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
