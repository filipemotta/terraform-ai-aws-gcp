# Build log, Act 1: the AWS floor, stack by stack, under the pack

This is the log of the session that built `aws/`. It is written by the agent that did the
work, in the order the work happened, with the real timestamps (UTC, 2026-09-15), the real
validate output, and the places where the pack corrected the agent or where the agent had to
deviate from it. Nothing here is reconstructed after the fact.

Environment: Terraform v1.12.1 (local), provider `hashicorp/aws` 6.64.0 (registry API,
published 2026-09-09), macOS, Claude Code agent session. No AWS credentials in the session:
every stack stops at `terraform validate`; `terraform plan` is recorded as *not executed*.

## Step 0: MCP setup (18:29–18:36)

What `docs/mcp-setup.md` describes was the first thing checked. Outcome in this session:

- Terraform MCP and Context7: configured in the workspace but **not exposed as tools to
  this agent context**. Fallback per the pack's anti-hallucination rule: provider docs
  fetched from the provider source at the pinned tag
  (`raw.githubusercontent.com/hashicorp/terraform-provider-aws/v6.64.0/website/docs/r/*.html.markdown`,
  which is the content `get_provider_details` serves), versions from the registry API
  (`registry.terraform.io/v1/providers/hashicorp/aws` → 6.64.0).
- While checking the official server's tool list (source, `pkg/tools/**`, v1.3.0): there is
  no `get_schema`, `terraform_init`, `terraform_validate` or `terraform_plan` tool. The
  pack's `CLAUDE.md` names all four. First gotcha, before a single line of
  HCL.
- Docs consulted before writing (all 2026-09-15): S3 backend (`use_lockfile`, lock file
  permissions Get/Put/Delete on `.tflock`, DynamoDB deprecated); AWS provider index
  (`assume_role`, `default_tags`); resource docs for every type used below; Claude Code
  hooks reference (`code.claude.com/docs/en/hooks`); EKS user guide (cluster and node IAM
  roles, access policies, standard-support versions: 1.36 newest); RDS PostgreSQL release
  notes (18 newest production major); IAM policy grammar.

## Step 1: install the pack (18:36:04)

```
cp terraform-architect-pack/CLAUDE.md aws/CLAUDE.md
cp -r terraform-architect-pack/.claude aws/.claude
```

`CLAUDE.md` is 74 lines, not the 80 the README advertises. Bootstrap block filled with the
placeholders (`atlas`, `123456789012`, `atlas-us-east-1-bucket-terraform-state`,
`us-east-1`, the two role ARNs). Nothing else in the pack edited.

Hooks: the original hooks file (`hooks-devops.json`) uses a `prompt`-type PreToolUse hook
(an LLM judges the command) and a PostToolUse command that reads
`$CLAUDE_TOOL_FILE_PATH`. The current
hooks reference documents stdin JSON (`tool_input.file_path`, `tool_input.command`) and
lists no such environment variable. I wrote three `command` hooks that read stdin
(`.claude/hooks/*.sh`) and wired them in `.claude/settings.json`; deterministic, and
testable with `shellcheck` and sample payloads. The `prompt` hook is a legitimate choice;
it just is not testable offline. Second gotcha: the env var.

Workspace check: the pack asks for `terraform workspace show` at session start. With no
backend initialised the answer is `default`. Noted; it matters two minutes later.

## Stack 00-remote-backend (18:38:54 → 18:40:41, 2 validate runs)

Prompt to myself, as the pack's `tf-scaffold-stack` skill sequences it: next number (none
exist → `00`), kebab-case name, skeleton, init, validate. The skill wants
`provider.tf` + `backend.tf` + `main.tf`(resources) + `variables.tf` + `outputs.tf` +
`README.md`. Convention 9 wants `main.tf` (terraform{} + provider{} only),
`variables.tf`, `outputs.tf`, `datasources.tf`, one kebab-case file per resource group. The
convention document said `main.tf` while the scaffold skill produced `provider.tf` +
`backend.tf`, so the stacks follow the convention; I kept the skill's `README.md` (it costs
nothing and the `tf-outputs-review` skill needs it). Divergence #1 between the scaffold
skill and the conventions, recorded in `gotchas-and-conventions.md`.

Files: `main.tf`, `variables.tf` (`tags`, `assume_role`, `remote_backend` object),
`s3-bucket.tf` (bucket + versioning + SSE + public access block, all labelled `this`),
`outputs.tf`, `README.md`. Backend key `remote-backend/remote-backend.tfstate`
(convention 2: `<stack>/<stack>.tfstate`; the skill says `NN-<name>/terraform.tfstate`,
divergence #2).
Chicken-and-egg documented in `main.tf` and the README.

Validate run 1: **fail**.

```
Error: Invalid index
  on main.tf line 49, in provider "aws":
  49:     role_arn = local.workspace_role_arn[terraform.workspace]
    │ local.workspace_role_arn is object with 3 attributes
    │ terraform.workspace is "default"
The given key does not identify an element in this collection value.
```

Convention 3, copied faithfully, does not validate in the workspace a
fresh checkout is in. `terraform validate` evaluates `terraform.workspace` (it is
`"default"`), and the map has `sandbox`, `staging`, `production`. The PostToolUse hook
would have surfaced exactly this after the Write.

Fix, and a design decision: `lookup(local.workspace_role_arn, terraform.workspace,
var.assume_role.role_arn)` with `var.assume_role.role_arn` defaulting to the **plan-only**
role. Unknown workspaces, `default` included, fail closed. It also gives the convention's
`assume_role.role_arn` field a job (in the workspace-aware variant it was dead weight).

Validate run 2: `Success! The configuration is valid.` Third gotcha.

Plan: not executed (no credentials). Cost: nothing billable beyond a few cents of S3.

## Stack 01-networking (18:41:28 → 18:42:14, 1 validate run)

`main.tf` derived from 00 by changing only the backend key (`networking/networking.tfstate`);
the provider block is identical across stacks, as convention 3 demands. `variables.tf`: the
`vpc` object from convention 4, verbatim in shape, with `enable_dns_support` /
`enable_dns_hostnames` added because EKS needs hostnames on. Two public + two private
subnets in `us-east-1a`/`1b`, `count` over the lists, `this` for IGW/EIP/NAT, `main` for the
VPC, role labels for subnets and route tables. Names: `vpc-atlas-useast1`,
`igw-atlas-useast1`, `nat-gateway-atlas-useast1`, `public-subnet-1`… per convention 8.

Two things the pattern forced me to decide:

- **One NAT gateway.** The pattern's example has one; production wants one per AZ. Kept one,
  said why in the file. The cost reviewer would flag a per-AZ NAT anyway at POC scale.
- **`Name` only.** Convention 7 forbids any tag but `Name` on resources. EKS load balancer
  discovery wants `kubernetes.io/role/elb` / `internal-elb` on subnets. The floor has no
  load balancers, so the rule holds today, but the rule as written has no exception clause
  and will need one the day an ingress lands. Fourth gotcha.

Validate run 1: `Success!`. Plan: not executed.

## Stack 02-eks (18:43:23 → 18:44:18, 1 validate run + 1 self-correction)

`tf-cross-stack` step 1 first: read `01-networking/outputs.tf` (`vpc`, `public_subnets_ids`,
`private_subnets_ids`, …). Then `datasources.tf` with `data "terraform_remote_state"
"network"` (short name, convention 11) and `locals` normalising the three values I consume.

`variables.tf`: one `eks` object; managed policy ARNs as lists inside it so
`aws_iam_role_policy_attachment` uses `count` (convention 6) instead of one resource per
policy. Policies from the EKS user guide, verified today: cluster `AmazonEKSClusterPolicy`;
node `AmazonEKSWorkerNodePolicy` + `AmazonEC2ContainerRegistryPullOnly` (the EKS user guide
now recommends PullOnly over ReadOnly) + `AmazonEKS_CNI_Policy` (the EKS user guide
recommends moving it to IRSA; kept on the node role for a floor with no add-ons stack).

Cluster: `version = "1.36"` (newest in standard support), `access_config` with
`authentication_mode = "API"` and `bootstrap_cluster_creator_admin_permissions = false`, so
the Terraform role has no Kubernetes access and the only cluster-admin is the explicit
`aws_eks_access_entry.admin` + `AmazonEKSClusterAdminPolicy` (ARN from the access policies
doc). Node group: `t4g.small` ×2, `AL2023_ARM_64_STANDARD` (value from the EKS API
reference), on-demand, 20 GiB.

Labels: convention 5's own example uses `aws_iam_role "eks-node-group"`, a hyphenated label.
Valid HCL, discouraged by the Terraform style guide. Used `cluster` / `node` (role labels).
Fifth (minor) gotcha.

Validate run 1: `Success!`. Then a self-correction the pack would have made in review: I
had put the two `aws_iam_policy_document` data sources in `eks-iam-role.tf`; convention 9
says data sources live in `datasources.tf`. Moved them; validate again `Success!`.

Plan: not executed. Cost (manual, see `measurement.md`): control plane + 2 nodes + EBS.

## Stack 03-data (18:44:54 → ~18:46, 1 validate run)

Two domains in one stack, so two objects: `rds` and `app_bucket` (convention 4 says one
object per domain; the stack has two domains). RDS: PostgreSQL `18`, `db.t4g.micro`, gp3 20
GiB, encrypted, `manage_master_user_password = true` (no password in state), subnet group
on the private subnets, security group with one ingress rule from the VPC CIDR
(`aws_vpc_security_group_ingress_rule`, the current resource, not the inline block),
`publicly_accessible = false`. POC flags explicit in the object with a comment:
`deletion_protection = false`, `skip_final_snapshot = true`. App bucket: same four resources
as the state bucket.

Validate run 1: `Success!`. Plan: not executed.

## The plan-only policy (18:46 → 18:47:18)

`iam/plan-only-policy.json` is convention 13's plan-only policy plus what the S3 backend doc
requires for the lock: `s3:PutObject` + `s3:DeleteObject` allowed only on
`arn:aws:s3:::<bucket>/*.tflock`, explicitly denied on every other key. With the read-only
policy as written, `terraform plan` on production dies acquiring the lock. Sixth gotcha, the
one the article is built around.

While writing it I could not find a wildcard service prefix (`*:Describe*`) in the
documented IAM action grammar (only `service:Action*` and bare `*`). No credentials to run
`access-analyzer validate-policy`, so I linted offline with `parliament` 1.6.4, which
expands `*:Describe*` across all services and reports only a LOW "unnecessary Resource *".
Kept that form for now; live validation is listed as pending in `TESTES.md`.

## After the stacks: two things the pack did not catch

1. **Hooks tested with real payloads (18:47 → 18:50).** `pre-tool-guard.sh` denies
   `terraform destroy` (no `-target`), `terraform apply -auto-approve`, and
   apply/destroy/import/state-mv/rm when the target directory's workspace is `production`
   (tested against a local-backend copy of stack 01 switched to a `production` workspace);
   allows plan and non-Terraform commands. `post-tool-tf-validate.sh` formats and validates
   the edited stack, and on an invented attribute (`cidr_blok`) returns exit 2 with the
   validate error on stderr, which is what the agent sees. `stop-verify.sh` blocks the turn
   on an unformatted file and approves a clean tree.
2. **`terraform_remote_state` and workspaces (18:49).** Reading the GCS backend doc for Act
   2 (`<prefix>/<workspace>.tfstate`) made me check the S3 one: named workspaces store state
   at `env:/<workspace>/<key>`. Convention 11's block has no `workspace`
   argument, so in a `sandbox` session `02-eks` would read the *default* workspace's
   `networking/networking.tfstate`, which this layout never writes. Added `workspace =
   terraform.workspace` to both downstream stacks with a comment; both re-validated green.
   Seventh gotcha, and the most consequential one: the conventions' role selection depends
   on named workspaces, and their cross-stack wiring silently assumes the default one.

## Iterations and blockers, in one place

| Stack | validate runs to green | What failed | Fix |
|---|---|---|---|
| 00-remote-backend | 2 | `Invalid index` on `local.workspace_role_arn[terraform.workspace]` | `lookup()` with plan-only fallback |
| 01-networking | 1 | — | — |
| 02-eks | 1 (+1 after moving data sources) | — | data sources to `datasources.tf` |
| 03-data | 1 | — | — |
| 02/03 (later) | 1 each | — | `workspace = terraform.workspace` on remote_state |

Not executed: `terraform plan` (no credentials), `/infracost:scan` (CLI needs an
interactive login; see `measurement.md`), `terraform apply` (human, by design).

## Post-review addendum (same day, after the editorial review)

Two things changed after this log was closed, recorded here rather than rewritten above.

1. **The plan-only policy was redesigned (gotcha 9).** The doubt logged at 18:46 was
   right: IAM's `Action` grammar is `<service>:<action>` with wildcards only in the action
   name, and `*:Describe*` is not a documented form; `parliament` accepts it by expanding
   it, which is why the offline lint was quiet. `iam/plan-only-policy.json` is gone.
   `iam/README.md` now describes the role as the AWS managed `ReadOnlyAccess` (the reads,
   maintained by AWS) + `iam/plan-only-state.json` (state read, `.tflock` write, explicit
   deny on other object writes; no `DenyEverythingElse`, IAM denies by default) + a
   permissions boundary `iam/plan-only-boundary.json` as the hard ceiling. The two
   `.tflock` statements are unchanged. The `main.tf` comment in every stack now points at
   `iam/README.md`.
2. **The pack was aligned to the conventions (gotcha 6).** The divergences logged at
   18:38 (`provider.tf`/`backend.tf`, `NN-<name>/terraform.tfstate`, `~> 5.0`) were only
   the visible part; `var.region`, `<env>-<role>-<index>` names, `optional()` defaults and
   a second tag layer were in the same skills. Both packs now carry the thirteen
   conventions plus the corrections of this log (fail-closed `lookup()`, `workspace` on
   remote_state, the lock exception, the grammar redesign), the real Terraform MCP tool
   names, and `/infracost:scan` as the plugin actually names it. The scaffold skill was
   re-run on a throwaway `04-observability`: skeleton and first resource validate in the
   `default` workspace; the same files with the direct map index fail with
   `Invalid index` on the first resource, and the original `variables.tf` snippet
   does not parse at all (single-line block with two arguments).

