# Terraform with an AI agent: one set of conventions, AWS then GCP

Two Terraform estates built with an AI agent (Claude Code) under one set of conventions,
and the logs of how they were built. The conventions live in the repository as files the
agent reads on every turn: an always-on `CLAUDE.md`, three subagents, five skills and three
hooks.

- `aws/` ... the AWS floor: state bucket, VPC, EKS, RDS + S3. Built first, stack by stack.
- `gcp/` ... the same floor on Google Cloud: state bucket, VPC, GKE, Cloud SQL + GCS. Built
  second, with the AWS stacks as the specification.
- `docs/` ... the build log of each act, the gotchas, the convention-by-convention diff,
  the measurement.

Everything validates offline (`bash validate.sh`). Nothing here applies anything: `apply`
is a human step by design, and this repository was never applied by its author.

## Layout

```
.
├── README.md
├── validate.sh                      # fmt + init -backend=false + validate on all 8 stacks, shellcheck, jq
├── aws/                             # the repository as the agent built it under the setup
│   ├── CLAUDE.md                    # the setup's slim always-on file, bootstrap values filled
│   ├── .mcp.json                    # Terraform MCP + Context7 for anyone who clones
│   ├── .claude/
│   │   ├── agents/                  # terraform-architect, terraform-cost-reviewer, terraform-security-reviewer
│   │   ├── skills/                  # tf-scaffold-stack, tf-variables-review, tf-naming-review, tf-cross-stack, tf-outputs-review
│   │   ├── hooks/                   # pre-tool-guard.sh, post-tool-tf-validate.sh, stop-verify.sh
│   │   └── settings.json            # PreToolUse / PostToolUse / Stop wiring
│   ├── iam/                         # the production plan-only role: ReadOnlyAccess + plan-only-state.json + plan-only-boundary.json
│   └── terraform/
│       ├── 00-remote-backend/       # S3 state bucket (versioned, encrypted, private)
│       ├── 01-networking/           # VPC, 2 AZs, public + private subnets, IGW, 1 NAT, route tables
│       ├── 02-eks/                  # EKS 1.36, t4g.small x2, IAM roles, admin access entry
│       └── 03-data/                 # RDS PostgreSQL 18 db.t4g.micro (private), app bucket
├── gcp/                             # the repository as the agent ported it
│   ├── CLAUDE.md                    # same agent files, GCP flavor (cloud-specific lines marked `GCP:`)
│   ├── .mcp.json                    # + gcloud MCP
│   ├── .claude/                     # same agents/skills/hooks, cloud-specific lines marked `GCP:`
│   ├── iam/plan-only-role.md        # the production plan-only service account
│   └── terraform/
│       ├── 00-remote-backend/       # GCS state bucket + project APIs
│       ├── 01-networking/           # custom VPC, subnet + secondary ranges, Cloud Router + NAT
│       ├── 02-gke/                  # GKE regional, private nodes, Workload Identity, e2-small x2
│       └── 03-data/                 # Cloud SQL PostgreSQL 18 db-f1-micro (private IP), app bucket
└── docs/
    ├── mcp-setup.md                 # step 0: the MCP servers and plugins the loop needs
    ├── build-log-aws.md             # Act 1, as it happened
    ├── port-log-gcp.md              # Act 2, as it happened
    ├── gotchas-and-conventions.md   # nine gotchas, the 13 conventions AWS vs GCP, the setup diff
    └── measurement.md               # size, time, iterations, cost per cloud
```

Each stack has its own `README.md` (purpose, provisions, consumes, provides, and for GCP the
resource-by-resource translation from its AWS twin).

## The story in two acts

**Act 1.** An empty repository gets the setup (`CLAUDE.md`, three subagents, five skills,
three hooks). The agent builds the AWS floor following the loop for every stack:
workspace check, provider docs for every resource, write, `terraform validate`, plan (not
run here: no credentials), cost review, human apply. `docs/build-log-aws.md` records where
the setup corrected the agent and where a convention, followed literally, broke:
`terraform validate` rejects the workspace-map lookup in the `default` workspace; a
plan-only IAM role that can only read cannot acquire the native S3 lock, and the read-all
wildcard form it is usually written in is not one IAM's grammar defines;
`terraform_remote_state` without `workspace` reads the wrong state once workspaces are in
play. All nine are in `docs/gotchas-and-conventions.md`.

**Act 2.** The setup gets a GCP flavor (backend gcs, provider google with `default_labels`
and service account impersonation, a plan-only service account). The agent ports stack by
stack with the AWS stack as the spec. `docs/port-log-gcp.md` records what stayed identical
(file layout, one object per domain, `this`/`main`, outputs, README shape, hooks) and what
had to change (backend block, provider auth, tags to labels, remote_state config, the
lock exception). `docs/gotchas-and-conventions.md` scores it: 8 of 13 conventions untouched
in the stacks, and the same 8 in the setup text once both flavors carried the same
conventions.

## Reproduce

### 0. Before the first prompt

Read `docs/mcp-setup.md`: install the Terraform MCP, Context7, the AWS plugin (or gcloud
MCP), and the Infracost plugin, and check `claude mcp list` shows them connected. Each of
`aws/` and `gcp/` is meant to be opened as its own Claude Code project (its `CLAUDE.md`,
`.claude/` and `.mcp.json` apply from that root).

### 1. Validate everything, free

```bash
git clone https://github.com/filipemotta/terraform-ai-aws-gcp && cd terraform-ai-aws-gcp
bash validate.sh
```

Runs `terraform fmt -check`, `terraform init -backend=false`, `terraform validate` in all
eight stacks, `shellcheck` on the hooks, `jq` on every JSON file. Requires Terraform >= 1.10
(tested with 1.12.1), no credentials.

### 2. Plan and apply, by a human

Prerequisites per cloud: the identities the provider blocks assume
(`terraform-apply` / `terraform-plan-readonly` roles on AWS; `terraform-apply@` /
`terraform-plan@` service accounts on GCP), and permission to create them. The bootstrap
values live in each `CLAUDE.md` and in `variables.tf` defaults; replace `123456789012`,
`atlas-demo-123` and the bucket names before anything else.

```bash
cd aws/terraform/00-remote-backend        # or gcp/terraform/00-remote-backend
# first apply only: comment out the backend block (see the stack README)
terraform workspace new sandbox
terraform init
terraform plan -out tfplan               # the agent stops here
terraform apply tfplan                   # a human runs this
# then uncomment the backend block and: terraform init -migrate-state
```

Then `01-networking`, `02-eks` / `02-gke`, `03-data`, in order, each with
`terraform workspace select sandbox && terraform init && terraform plan -out tfplan` and a
human `terraform apply tfplan`. On the `production` workspace the provider assumes the
plan-only identity and `apply` is rejected by the cloud, not just by the hook.

Estimated cost while the floor exists: about $152/month on AWS and $114/month on GCP
(`docs/measurement.md`; the GCP number has unverified lines). Both under the $250 POC
guardrail.

### 3. Tear down, by a human

Reverse order, `03-data` first, `00-remote-backend` last. The hooks block
`terraform destroy` without `-target` for the agent; humans run it directly:

```bash
cd aws/terraform/03-data && terraform workspace select sandbox && terraform destroy
cd ../02-eks && terraform destroy
cd ../01-networking && terraform destroy
cd ../00-remote-backend && terraform init -migrate-state   # move state back to local first
# (comment out the backend block, answer yes), then: terraform destroy
```

`deletion_protection` is `false` and `skip_final_snapshot` is `true` on the POC database
objects on purpose; the stack READMEs say what production flips.

## Measurement at a glance

| | AWS (Act 1) | GCP (Act 2) |
|---|---|---|
| Stacks / files / HCL lines | 4 / 30 / 950 | 4 / 27 / 823 |
| Resource blocks | 32 | 18 |
| Wall time (agent files + stacks + IAM) | 11 min 14 s | 7 min 10 s |
| Stack time, sum of the 4 stack intervals (no gaps) | ~4 min 28 s | 2 min 23 s |
| Stack time, first start to last end (with gaps) | ~7 min 06 s | 3 min 07 s |
| validate runs to green (failures) | 6 (1) | 5 (1, formatting) |
| Estimated monthly cost | ≈ $152 | ≈ $114 |

Details, caveats and sources: `docs/measurement.md`.

## Versions

Terraform 1.12.1; `hashicorp/aws` ~> 6.0 (6.64.0 at build time); `hashicorp/google`
~> 8.0 (8.2.0 at build time); EKS 1.36; PostgreSQL 18 on both clouds. Hooks follow the
Claude Code hooks reference as of 2026-09-15.

## License

MIT. Placeholders only: account `123456789012`, project `atlas-demo-123`, platform `atlas`.
