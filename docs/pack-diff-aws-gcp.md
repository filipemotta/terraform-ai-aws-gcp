# The 13 patterns, AWS vs GCP: what is the pattern and what is the cloud

One row per pattern of the guide's Terraform architecture, with how it materialised in
`aws/` and in `gcp/`. The last column says whether the port had to change anything. This is
the table the thesis rests on: the conventions are the prompt, and most of them do not
mention a cloud.

| # | Pattern (guide) | AWS (`aws/terraform`) | GCP (`gcp/terraform`) | Changed in the port? |
|---|---|---|---|---|
| 1 | Numbered stacks, state per stack | `00-remote-backend`, `01-networking`, `02-eks`, `03-data` | `00-remote-backend`, `01-networking`, `02-gke`, `03-data` | No (one directory renamed for the product) |
| 2 | Remote backend, native lock, encrypted | `backend "s3"` with `use_lockfile = true`, `encrypt = true`, `key = <stack>/<stack>.tfstate` | `backend "gcs"` with `prefix = <stack>`; locking and encryption are built in; object is `<prefix>/<workspace>.tfstate` | Yes: block shape; the `<stack>/<stack>.tfstate` key rule cannot be reproduced (GCS names the object after the workspace) |
| 3 | Provider with delegated identity + default tags, identical in every stack | `assume_role { role_arn }` from a workspace map; `default_tags { tags = var.tags }`; region from `var.assume_role.region` | `impersonate_service_account` from a workspace map; `default_labels = var.labels`; project/region from `var.impersonation` | Yes: argument names; the workspace map and the fail-closed `lookup()` are identical |
| 4 | Variables: `tags` + `assume_role` in every stack, one nested object per domain with inline defaults | `tags`, `assume_role`, then `remote_backend` / `vpc` / `eks` / `rds` + `app_bucket` | `labels`, `impersonation`, then `remote_backend` + `project` / `vpc` / `gke` / `sql` + `app_bucket` | No in shape; two names differ (`tags`→`labels`, `assume_role`→`impersonation`) |
| 5 | Labels `this` / `main` / role | `aws_vpc.main`, `aws_nat_gateway.this`, `aws_subnet.public`, `aws_iam_role.cluster` | `google_compute_network.main`, `google_compute_router_nat.this`, `google_service_account.node` | No |
| 6 | `count` for plural resources | `aws_subnet.public[count.index]`, `aws_iam_role_policy_attachment.node[count.index]` | `google_project_service.this[count.index]`, `google_project_iam_member.node[count.index]` | No; clarification: nested block lists (`secondary_ip_range`) need `dynamic`, not `count` |
| 7 | Only `Name` on resources; globals via the provider | `tags = { Name = … }` on every taggable resource | no per-resource labels at all; identity is the `name` argument | Yes: GCP has no `Name` label because every resource has `name` |
| 8 | Name convention `<type>-<project>-<condensed-region>` | `vpc-atlas-useast1`, `nat-gateway-atlas-useast1`, `eks-cluster-atlas` | `vpc-atlas-uscentral1`, `nat-atlas-uscentral1`, `gke-cluster-atlas` | No (region token differs) |
| 9 | Files: `main.tf` (terraform + provider only), `variables.tf`, `outputs.tf`, `datasources.tf`, kebab-case per resource group | `vpc.tf`, `nat-gateway.tf`, `route-table-public.tf`, `eks-cluster.tf`, `rds-instance.tf`… | `vpc.tf`, `cloud-nat.tf`, `gke-cluster.tf`, `sql-instance.tf`… | No |
| 10 | Outputs: whole object for singletons, splat for plurals, snake_case | `vpc`, `private_subnets_ids`, `public_subnet_arn` | `network`, `subnetwork`, `pods_range_name`, `enabled_services` (splat) | No |
| 11 | Cross-stack via `terraform_remote_state` in `datasources.tf` + locals | `backend = "s3"`, `config = { bucket, key, region }` | `backend = "gcs"`, `config = { bucket, prefix }` | Yes: config keys; both gained `workspace = terraform.workspace` (not in the guide) |
| 12 | New-stack checklist | followed for 4 stacks | followed for 4 stacks | No |
| 13 | Hard guardrail: plan-only identity on production | IAM role `terraform-plan-readonly` with `iam/plan-only-policy.json` | service account `terraform-plan@…` with `roles/viewer` + bucket roles (`iam/plan-only-role.md`) | Yes: mechanism; and both needed the lock exception (`.tflock` write) the guide does not have |

Score: 8 patterns untouched, 5 touched, and of those 5, three are the same *idea* with
different argument names (2, 3, 11). Only 7 (tags vs labels) and 13 (IAM vs service
account) are genuinely different mechanisms.

## Beyond the 13: pack vs monolith, and pack vs reality

Things found while following the pack that the guide should know about.

| Where | What the pack/guide says | What happened |
|---|---|---|
| `tf-scaffold-stack` skill | skeleton is `provider.tf` + `backend.tf` + `main.tf` (resources) + …; key `NN-<name>/terraform.tfstate`; provider `~> 5.0` | Monolith section 9 says `main.tf` holds only `terraform{}` + `provider{}`, one file per resource, key `<stack>/<stack>.tfstate`, provider `~> 6.0`. Followed the monolith. The skill and the monolith disagree on three points. |
| `CLAUDE.md` (pack) tooling | Terraform MCP tools `get_schema`, `terraform_init`, `terraform_validate`, `terraform_plan` | The official server (v1.3.0) has none of them. Schema = `search_providers` → `get_provider_details`; init/validate/plan = Bash. |
| `hooks-devops.json` PostToolUse | reads `$CLAUDE_TOOL_FILE_PATH` | Not in the hooks reference; input is stdin JSON `tool_input.file_path`. Rewritten as command hooks that read stdin. |
| Monolith section 3 | `local.workspace_role_arn[terraform.workspace]` | Fails `terraform validate` in the `default` workspace (`Invalid index`). Fixed with `lookup()` falling back to the plan-only identity. |
| Monolith section 11 | `terraform_remote_state` with no `workspace` | With named workspaces, S3 stores state at `env:/<workspace>/<key>` and GCS at `<prefix>/<workspace>.tfstate`; the block reads the default workspace's state. Added `workspace = terraform.workspace`. |
| Monolith section 13 | plan-only policy with Get/List on the state bucket only | Native S3 locking needs Put/Delete on `<key>.tflock`; `terraform plan` fails before reading a resource. Same on GCS (Object Admin per the doc). Fixed with a `.tflock`-scoped allow (S3) / conditional binding (GCS), or `-lock=false`. |
| Monolith section 7 | only `Name` on resources | EKS subnet discovery tags (`kubernetes.io/role/*`) would violate it; the rule needs an exception clause for cloud-required tags. |
| Monolith section 5 example | `aws_iam_role "eks-node-group"` | Hyphenated resource label; valid, discouraged by the Terraform style guide. Used `node`. |
| Pack README | "80 lines" | 74 lines as shipped; 76 (AWS) and 78 (GCP) after bootstrap values and the flavor note. |
| Monolith section 2 / skill | `version = "~> 6.0"` vs `"~> 5.0"` | Registry today: 6.64.0. Skill is behind the monolith. |
| Monolith section 4.2 | one object per domain | A stack with two domains (`03-data`: database + bucket) gets two objects; the rule reads better as "one object per domain, not per stack". |
