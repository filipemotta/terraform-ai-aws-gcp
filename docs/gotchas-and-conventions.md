# Gotchas and conventions

The technical record behind the two estates in this repository, in three parts:

1. **Nine gotchas** the two builds hit, with the fix that shipped for each.
2. **The thirteen conventions, AWS against GCP**: what the port had to change and what it
   did not, for the stacks and for the setup text.
3. **Two defects and four clarifications** in the convention text itself.

Everything here was hit while building, not read about. The numbering of the gotchas is the
one `build-log-aws.md` and `port-log-gcp.md` use.

## Part 1: nine gotchas

| # | Where | The obvious version | What happens, and what ships here |
|---|---|---|---|
| 1 | Tooling rule in `CLAUDE.md` | Terraform MCP tools named `get_schema`, `terraform_init`, `terraform_validate`, `terraform_plan` | The official server (v1.3.0) has none of them: its registry toolset is `search_providers`, `get_provider_details`, `get_provider_capabilities`, `get_latest_provider_version` and the module/policy equivalents, plus HCP Terraform workspace and run tools. The schema step is `search_providers` → `get_provider_details`; `init`, `validate` and `plan` are CLI commands run through Bash. A model told to call a tool that does not exist stalls or improvises, which is the failure the rule exists to prevent. Both clouds' agent files name the real tools. |
| 2 | Hook input | a PostToolUse hook reading `$CLAUDE_TOOL_FILE_PATH` | No such environment variable is documented. Hook input is JSON on stdin: `tool_input.file_path` for `Edit`/`Write`, `tool_input.command` for `Bash`, plus `cwd` and `tool_name`. The hooks here (`.claude/hooks/*.sh`) parse stdin with `jq`. A `prompt`-type hook is a legitimate alternative; it is just not testable offline, and a `command` hook is. |
| 3 | Provider identity by workspace (convention 3) | `local.workspace_role_arn[terraform.workspace]` | Fails `terraform validate` in the `default` workspace with `Invalid index`, because the map holds `sandbox`, `staging` and `production`. The nuance: Terraform only evaluates a provider block once a resource uses it, so an empty skeleton validates green and the failure appears on the first real resource. Fixed with `lookup(local.workspace_role_arn, terraform.workspace, var.assume_role.role_arn)`, whose fallback is the plan-only identity: unknown workspaces fail closed, and the `assume_role.role_arn` field gets a job. |
| 4 | Cross-stack reads (convention 11) | `terraform_remote_state` with no `workspace` | With named workspaces, S3 stores state at `env:/<workspace>/<key>` and GCS at `<prefix>/<workspace>.tfstate`, so the block silently reads the *default* workspace's state. `workspace = terraform.workspace` added in both clouds. This is the sharp one: the identity rule depends on named workspaces while the cross-stack wiring assumes the default one. |
| 5 | Plan-only identity against the native lock (convention 13) | read on the state bucket and nothing else | Native S3 locking (`use_lockfile = true`) creates `<key>.tflock` and deletes it when done; the backend documentation requires `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the lock file. GCS asks for Storage Object Admin on the bucket. So a read-only identity cannot acquire the lock and `terraform plan` on production dies before reading a single resource. Two exits: `-lock=false`, or let the identity write the lock marker and nothing else. Shipped: `PutObject`/`DeleteObject` scoped to `*.tflock` with an explicit deny on every other key (`aws/iam/plan-only-state.json`), and `roles/storage.objectUser` under an IAM condition `resource.name.endsWith(".tflock")` (`gcp/iam/plan-only-role.md`). |
| 6 | **Convention drift: the document and the files that implement it** (`terraform-architect` agent, `tf-scaffold-stack`, `tf-naming-review`, `tf-variables-review`, `tf-cross-stack`) | one set of conventions written twice, once as prose and once as the agent files that apply it | The two copies drift, and nothing tells you: the prose stays right while the files the agent actually reads teach something else. Seven points had drifted here, and they are the checklist for any setup like this one. File layout: `provider.tf` + `backend.tf` + resources in `main.tf`, against convention 9 (`main.tf` holds only `terraform{}` + `provider{}`, one kebab-case file per resource group, `datasources.tf`). State key `NN-<name>/terraform.tfstate` against `<stack>/<stack>.tfstate` (conventions 2 and 11). A loose `region = var.region` against convention 3's `var.assume_role.region`. Names `<env>-<role>-<index>` such as `prod-web-01` against convention 8's `<type>-<project>-<condensed-region>`. `optional()` per field with `default = {}` against convention 4's complete inline default. A second layer of resource tags (`Purpose`, `Retention`) in `tf-naming-review` against convention 7's "only `Name`". A `~> 5.0` provider pin against convention 2's `~> 6.0`. The stacks follow the convention document throughout; both clouds' agent files here carry the thirteen conventions plus gotchas 3, 4, 5 and 9, and a throwaway `/tf-scaffold-stack 04-observability` under the aligned skill validates in `default` with a resource in it. Symptom to watch for: a scaffold that looks green until the first real resource lands. |
| 7 | "Only `Name`" (convention 7) | no tag on a resource except `Name` | Managed services use tags as an API. EKS load balancer discovery wants `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb` on subnets, so the rule as written breaks the day an ingress lands. It now reads "only `Name`, plus the tags a managed service requires for discovery, listed in the stack README". |
| 8 | Cloud SQL edition (GCP data stack) | nothing about editions | `POSTGRES_16` and later default to the `ENTERPRISE_PLUS` edition, which supports only the performance-optimised machine types and rejects shared-core tiers such as `db-f1-micro` at create time (`Invalid Tier (...) for (ENTERPRISE_PLUS) Edition`). `edition = "ENTERPRISE"` is explicit in the `sql` object with the reason in a comment. The AWS twin has no equivalent trap. |
| 9 | **IAM action grammar** (convention 13, and the first version of the plan-only policy here) | `"*:Describe*"`, `"*:List*"`, `"*:Get*"` as `Action` values, plus a `DenyEverythingElse` built on the same strings in `NotAction` | IAM's `Action` element is `<service>:<action>`: the documented grammar allows wildcards inside the action name (`s3:Get*`, `iam:*AccessKey*`), the whole-service form (`s3:*`) and the bare `*`, never in the service namespace. Offline linters do not catch it — `parliament` expands `*:Describe*` across every service it knows and reports nothing. Redesigned as three pieces: `arn:aws:iam::aws:policy/ReadOnlyAccess` (AWS enumerates and maintains the read actions), `iam/plan-only-state.json` (state read, `.tflock` write, explicit deny on other object writes, no `DenyEverythingElse` because IAM denies by default), and a permissions boundary `iam/plan-only-boundary.json` as the ceiling, with per-service read patterns because a boundary is a single managed policy and cannot compose `ReadOnlyAccess` with a second one. |

## Part 2: the thirteen conventions, AWS against GCP

One row per convention, with how it materialised in `aws/` and in `gcp/`. The last column
says whether the port had to change anything. This is the table the thesis rests on: the
conventions are the prompt, and most of them do not mention a cloud.

| # | Convention | AWS (`aws/terraform`) | GCP (`gcp/terraform`) | Changed in the port? |
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
| 11 | Cross-stack via `terraform_remote_state` in `datasources.tf` + locals | `backend = "s3"`, `config = { bucket, key, region }` | `backend = "gcs"`, `config = { bucket, prefix }` | Yes: config keys; both gained `workspace = terraform.workspace` (gotcha 4) |
| 12 | New-stack checklist | followed for 4 stacks | followed for 4 stacks | No |
| 13 | Hard guardrail: plan-only identity on production | IAM role `terraform-plan-readonly`: `ReadOnlyAccess` + `iam/plan-only-state.json` + permissions boundary `iam/plan-only-boundary.json` | service account `terraform-plan@…` with `roles/viewer` + bucket roles (`iam/plan-only-role.md`) | Yes: mechanism; and both needed the lock exception (`.tflock` write) a plain read-only identity does not have (gotcha 5) |

Score for the stacks: 8 conventions untouched, 5 touched, and of those 5, three are the same
*idea* with different argument names (2, 3, 11). Only 7 (tags vs labels) and 13 (IAM vs
service account) are genuinely different mechanisms.

### The setup text: `diff -r aws/.claude gcp/.claude`

Both flavors carry the same thirteen conventions and the fixes of Part 1; every agent file
opens with the note `Conventions v2: the thirteen patterns plus the fixes the AWS build
surfaced`. What is left between them is cloud, and it is measurable:

| Agent file | AWS lines | GCP lines | Lines differing (`diff`, `<` + `>`) |
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
are: every convention in the architect agent and every skill carries the full HCL example of
the rule, and an example is made of cloud nouns (`aws_vpc.main` against
`google_compute_network.main`, `assume_role` against `impersonate_service_account`,
`vpc-atlas-useast1` against `vpc-atlas-uscentral1`). Measured on prose only (code blocks and
lines tagged `GCP:` excluded), the architect agent's 13 sections differ by 84 lines, and the
rule text of conventions 1, 4, 5, 6, 8, 9, 10 and 12 differs only in the nouns of its
examples. That gives the setup text the same score as the stacks: 8 rules that did not move,
3 that kept the idea and changed the arguments (2, 3, 11), 2 whose mechanism is different
(7, 13). The hook logic did not change at all (4 lines of messages and patterns across three
scripts); `settings.json` is identical.

## Part 3: two defects and four clarifications

Two defects, both silent until something else fails:

| Where | Defect | What ships here |
|---|---|---|
| Stack skeleton for variables | `variable "tags" { type = map(string), default = {} }` is not valid HCL: a single-line block takes one argument, so the file fails to parse before any convention can be judged | the multi-line block with a complete `default`, as convention 4 asks |
| PostToolUse validate hook | a command hook runs in the session's working directory, so a bare `terraform validate` checks the cwd and not the stack that was edited; at a repository root with no `.tf` files it prints `Success! The configuration is valid.` and the hook reports "validated" for a file it never looked at | `post-tool-tf-validate.sh` reads `tool_input.file_path` from stdin and `cd`s into its directory before `fmt` and `validate` |

Four places where the convention text needed sharper words:

| Convention | Reading that needed sharpening | Now |
|---|---|---|
| 5 (labels) | the example `aws_iam_role "eks-node-group"` uses a hyphenated label: valid HCL, discouraged by the Terraform style guide | examples say `node` |
| 4 (variables) | "one object per domain" read as one object per stack | "one object per domain, not per stack": `03-data` has two domains, so two objects |
| 6 (`count` for plurals) | nested block lists such as `secondary_ip_range` cannot use `count` | the rule is about resources; nested blocks need `dynamic` + `for_each` |
| Agent-file size | an always-on file advertised as "80 lines" shipped at 74, and the count moves with every bootstrap edit | the setups here state no number |
