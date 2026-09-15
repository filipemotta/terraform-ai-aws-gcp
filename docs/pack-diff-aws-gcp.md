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
| 13 | Hard guardrail: plan-only identity on production | IAM role `terraform-plan-readonly`: `ReadOnlyAccess` + `iam/plan-only-state.json` + permissions boundary `iam/plan-only-boundary.json` | service account `terraform-plan@…` with `roles/viewer` + bucket roles (`iam/plan-only-role.md`) | Yes: mechanism; and both needed the lock exception (`.tflock` write) the guide does not have |

Score for the stacks: 8 patterns untouched, 5 touched, and of those 5, three are the same
*idea* with different argument names (2, 3, 11). Only 7 (tags vs labels) and 13 (IAM vs
service account) are genuinely different mechanisms.

## The pack after alignment: `diff -r aws/.claude gcp/.claude`

The packs in this repository were re-aligned to the chapter's 13 patterns and to the Act 1
corrections after the editorial review (see finding 6 below). Every changed pack file opens
with the note "Aligned with the chapter's 13 patterns and the Act 1 corrections". After
that alignment the two packs differ only by cloud, and the diff is measurable:

| Pack file | AWS lines | GCP lines | Lines differing (`diff`, `<` + `>`) |
|---|---|---|---|
| `CLAUDE.md` | 82 | 84 | 24 |
| `agents/terraform-architect.md` | 363 | 361 | 334 |
| `agents/terraform-cost-reviewer.md` | 107 | 109 | 24 |
| `agents/terraform-security-reviewer.md` | 105 | 106 | 43 |
| `skills/tf-scaffold-stack/SKILL.md` | 185 | 191 | 110 |
| `skills/tf-variables-review/SKILL.md` | 121 | 131 | 88 |
| `skills/tf-naming-review/SKILL.md` | 95 | 97 | 86 |
| `skills/tf-cross-stack/SKILL.md` | 148 | 150 | 82 |
| `skills/tf-outputs-review/SKILL.md` | 147 | 143 | 78 |
| `hooks/pre-tool-guard.sh` | 60 | 60 | 2 (the deny message names the identity) |
| `hooks/stop-verify.sh` | 43 | 43 | 2 (the secret patterns) |
| `hooks/post-tool-tf-validate.sh`, `settings.json` | 30 + 39 | 30 + 39 | 0 |
| **Total `.claude/`** | **1443** | **1460** | **849** |

849 of roughly 1450 lines differ, which looks like a lot until you look at what the lines
are: every pattern in the architect agent and every skill now carries the full HCL example
of the convention, and an example is made of cloud nouns (`aws_vpc.main` against
`google_compute_network.main`, `assume_role` against `impersonate_service_account`,
`vpc-atlas-useast1` against `vpc-atlas-uscentral1`). Measured on prose only (code blocks
and lines tagged `GCP:` excluded), the architect agent's 13 pattern sections differ by 84
lines, and the rule text of patterns 1, 4, 5, 6, 8, 9, 10 and 12 differs only in the nouns
of its examples. That gives the pack text the same score as the stacks: 8 patterns whose
rule did not move, 3 whose rule kept the idea and changed the arguments (2, 3, 11), 2 whose
mechanism is different (7, 13). The hook logic did not change at all (4 lines of messages
and patterns across three scripts); `settings.json` is identical.

## Beyond the 13: what the guide should know

Nine findings and four smaller notes, numbered as the article cites them.

| # | Where | What the pack/guide says | What happened |
|---|---|---|---|
| 1 | Pack `CLAUDE.md` tooling | Terraform MCP tools `get_schema`, `terraform_init`, `terraform_validate`, `terraform_plan` | The official server (v1.3.0) has none of them: its registry toolset is `search_providers`, `get_provider_details`, `get_provider_capabilities`, `get_latest_provider_version` and the module/policy equivalents, plus HCP Terraform tools. Schema = `search_providers` → `get_provider_details`; init/validate/plan = CLI via Bash. The packs in this repository now say so. |
| 2 | `hooks-devops.json` PostToolUse | reads `$CLAUDE_TOOL_FILE_PATH`; runs a bare `terraform validate` | The variable is not in the hooks reference; the input is stdin JSON `tool_input.file_path`. And a command hook runs in the session `cwd`, so the bare `terraform validate` validates the repository root, not the stack that was edited; at a root with no `.tf` files it prints `Success! The configuration is valid.` and the hook reports "validated" for a file it never checked. Rewritten as command scripts that read stdin and `cd` into the file's directory. |
| 3 | Monolith section 3 | `local.workspace_role_arn[terraform.workspace]` | Fails `terraform validate` in the `default` workspace (`Invalid index`) as soon as a resource uses the provider (a skeleton with no resources still validates, which is why a scaffold looks green until the first resource lands). Fixed with `lookup()` falling back to the plan-only identity. |
| 4 | Monolith section 11 | `terraform_remote_state` with no `workspace` | With named workspaces, S3 stores state at `env:/<workspace>/<key>` and GCS at `<prefix>/<workspace>.tfstate`; the block reads the default workspace's state. Added `workspace = terraform.workspace`. |
| 5 | Monolith section 13 | plan-only policy with Get/List on the state bucket only | Native S3 locking needs Put/Delete on `<key>.tflock`; `terraform plan` fails before reading a resource. Same on GCS (Object Admin per the doc). Fixed with a `.tflock`-scoped allow + explicit deny elsewhere (S3) / conditional binding (GCS), or `-lock=false`. |
| 6 | **Pack vs monolith drift** (`terraform-architect` agent, `tf-scaffold-stack`, `tf-naming-review`, `tf-variables-review`, `tf-cross-stack`) | The composed pack encodes conventions the monolith does not: pattern 9 lays out `provider.tf` + `backend.tf` + `main.tf` for resources (monolith: `main.tf` holds only `terraform{}` + `provider{}`, one kebab-case file per resource, `datasources.tf`); patterns 2 and 11 key state as `01-networking/terraform.tfstate` (monolith: `<stack>/<stack>.tfstate`); pattern 3 reads `region = var.region` (monolith: `var.assume_role.region`, a loose region variable is forbidden); pattern 8 names resources `<env>-<role>-<index>` like `prod-web-01` (monolith: `<type>-<project>-<condensed-region>`); pattern 4 uses `optional()` per field with `default = {}` (monolith: a complete `default = {...}`); `tf-naming-review` adds a second layer of resource tags (`Purpose`, `Retention`) against the monolith's "only `Name`"; `tf-variables-review` teaches `optional()`; the scaffold skill pins `~> 5.0` (monolith: `~> 6.0`, registry at 6.64.0). The scaffold skill's `variables.tf` snippet is also not valid HCL (`variable "tags" { type = map(string), default = {} }`: a single-line block takes one argument). | The stacks followed the monolith throughout. As published, `/tf-scaffold-stack 04-observability` under the AWS pack would have produced `provider.tf` at `~> 5.0` with `local.workspace_role_arn[terraform.workspace]`, a skeleton that fails `terraform validate` on its first resource in `default`. Both packs in this repository are now aligned to the monolith's 13 patterns and to findings 3, 4, 5 and 9; the scaffold skill was re-run on a throwaway `04-observability` and validates in `default` with a resource (evidence in the factory's test record). |
| 7 | Monolith section 7 | only `Name` on resources | EKS subnet discovery tags (`kubernetes.io/role/*`) would violate it. The rule now reads "only `Name`, plus the tags a managed service requires for discovery, listed in the stack README". |
| 8 | GCP flavor, data stack | (nothing about Cloud SQL editions) | `POSTGRES_16+` defaults to `ENTERPRISE_PLUS`, which rejects shared-core tiers such as `db-f1-micro` at create time. `edition = "ENTERPRISE"` is explicit in the `sql` object with the reason in a comment. |
| 9 | **IAM action grammar** (monolith section 13, and the first version of `aws/iam/plan-only-policy.json` in this repository) | `"*:Describe*"`, `"*:List*"`, `"*:Get*"` as `Action` values, and a `DenyEverythingElse` built on the same strings in `NotAction` | IAM's `Action` element is `<service>:<action>`; the documented grammar allows wildcards in the action name (`s3:Get*`), the whole-service form (`s3:*`) and the bare `*`, never in the service namespace. Offline linters do not catch it (`parliament` expands `*:Describe*` across every service and reports nothing). Redesigned: `arn:aws:iam::aws:policy/ReadOnlyAccess` (AWS enumerates and maintains the read actions) + `iam/plan-only-state.json` (state read, `.tflock` write, explicit deny on other object writes, no `DenyEverythingElse`: IAM denies by default) + a permissions boundary `iam/plan-only-boundary.json` as the hard ceiling, with per-service read patterns because a boundary is a single managed policy and cannot compose `ReadOnlyAccess` with a second one. |

Smaller notes:

| Where | What the pack/guide says | What happened |
|---|---|---|
| Monolith section 5 example | `aws_iam_role "eks-node-group"` | Hyphenated resource label; valid, discouraged by the Terraform style guide. Used `node`; the pack examples now say `node`. |
| Pack README | "80 lines" | 74 lines as shipped; the count moves with every bootstrap edit and alignment, so the packs here state no number. |
| Monolith section 4.2 | one object per domain | A stack with two domains (`03-data`: database + bucket) gets two objects; the rule reads better as "one object per domain, not per stack". |
| Monolith section 6 | `count` for plurals | Nested block lists (`secondary_ip_range`) need `dynamic` + `for_each`; the rule is about resources and now says so. |
