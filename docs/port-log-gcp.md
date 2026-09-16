# Port log, Act 2: the same floor on GCP, with the AWS stacks as the spec

Same author, same session, same rules as `build-log-aws.md`. Timestamps are UTC,
2026-09-15. Provider `hashicorp/google` 8.2.0 (registry API, published 2026-09-08). No GCP
credentials in the session: every stack stops at `terraform validate`.

The instruction to myself was the one the article makes: *do not design GCP; translate
AWS*. Each `gcp/terraform/NN-*` was written with the matching `aws/terraform/NN-*` open,
resource by resource, and the result of the translation is the table in each stack's
README.

## What changes in the pack (18:50:45 → 18:54:48)

Derived `gcp/CLAUDE.md`, the three agents, the five skills and the hooks from `aws/` by
substitution, never by rewriting. Every structurally changed line is marked `GCP:` and every
file opens with the same note, so `diff -r aws/.claude gcp/.claude` is the answer to "what is
cloud-specific in this pack". `CLAUDE.md` as first ported: 78 lines, 15 changed. What moved:

| Pack element | AWS | GCP |
|---|---|---|
| Identity line | "for AWS environments. Multi-account…" | "for Google Cloud environments. Multi-project…" |
| Hard guardrail sentence | `terraform-plan-readonly` IAM role | `terraform-plan@…` service account, impersonated |
| Context7 library | `/hashicorp/terraform-provider-aws` | `/hashicorp/terraform-provider-google` |
| Bootstrap block | account id, S3 bucket, two role ARNs | project id, GCS bucket, two service account emails |
| Convention 2 (architect agent, scaffold skill) | `backend "s3"` + `use_lockfile` + `encrypt` + `key` | `backend "gcs"` + `prefix` (native lock, encrypted by default) |
| Convention 3 | `assume_role { role_arn }` + `default_tags { tags }` | `impersonate_service_account` + `default_labels` |
| Conventions 7/8 (naming skill) | `Name` tag; as published the AWS skill named resources `<env>-<role>-<index>` (`prod-web-01`) | `name` argument; the port used convention 8's `<type>-<project>-<condensed-region>`, which the AWS stacks already followed, so the two flavors of the skill disagreed until the alignment below |
| Convention 11 (cross-stack skill) | `config = { bucket, key, region }` | `config = { bucket, prefix }` |
| Convention 13 | plan-only IAM policy JSON | `roles/viewer` + bucket roles, conditional `.tflock` write |
| Cost reviewer categories | EC2/EKS/NAT/RDS/CloudWatch | GCE/GKE/Cloud NAT/Cloud SQL/Cloud Logging |
| Security reviewer domains | IAM wildcards, ExternalId, KMS, SGs, CloudTrail | basic roles, SA keys, CMEK, firewall rules, Audit Logs |
| Hook messages | "terraform-plan-readonly role" | "terraform-plan service account"; secret grep looks for SA key JSON |
| `tf-variables-review`, `tf-outputs-review` | — | example resource names only; logic untouched |

At the time, ten of the thirteen convention sections in the pack text were left as they
were; what changed was the list the thesis predicts: backend, provider auth, tags-vs-labels,
remote_state config shape, the plan-only identity. The hooks did not change in logic.

**Post-review note (same day, after the editorial review).** The port started from the
original pack, and that pack disagreed with the convention document on several points
(gotcha 6 in `gotchas-and-conventions.md`: file layout, state key, `var.region`,
`<env>-<role>-<index>` names, `optional()` defaults, a second tag layer, the `~> 5.0` pin).
The convention document said `main.tf` with only `terraform` and `provider` while the
scaffold skill produced `provider.tf` + `backend.tf`, and the stacks follow the convention.
Both packs were then aligned to the thirteen conventions and to the Act 1 corrections
(fail-closed `lookup()`, `workspace` on remote_state, the lock exception, the IAM grammar
redesign of convention 13), and every changed file carries the note "Conventions v2: the
thirteen patterns plus the fixes the AWS build surfaced". After that, the AWS-to-GCP diff
is only cloud: 849 of ~1450 lines under `.claude/` differ, almost all of
them inside HCL examples made of cloud nouns; on the rule text of the architect agent, 8
conventions are untouched (1, 4, 5, 6, 8, 9, 10, 12), 3 keep the idea and change the
arguments (2, 3, 11), 2 are different mechanisms (7, 13); the hook logic is unchanged
(4 lines of messages and secret patterns) and `settings.json` is identical. `CLAUDE.md`:
82 lines on AWS, 84 on GCP, 24 differing. The per-file table is in
`gotchas-and-conventions.md`.

## Stack 00-remote-backend (18:54:48 → 18:55:25, 1 validate run)

Spec: `aws/terraform/00-remote-backend`. Translation:

| AWS | GCP |
|---|---|
| `aws_s3_bucket.this` | `google_storage_bucket.this` |
| `aws_s3_bucket_versioning.this` | `versioning { enabled = true }` (argument) |
| `aws_s3_bucket_server_side_encryption_configuration.this` | none: encrypted by default |
| `aws_s3_bucket_public_access_block.this` | `public_access_prevention = "enforced"` (argument) |
| — | `google_project_service.this[*]` (six APIs the other stacks call; AWS has no such step) |

Four resources became one, and one new resource appeared that has no AWS counterpart. The
`project` object (with its `services` list) is the second domain object of the stack.
Provider block: `lookup(local.workspace_service_account, terraform.workspace,
var.impersonation.service_account)`, the fail-closed shape from Act 1, carried over as is.
Backend: `prefix = "remote-backend"`; the state object becomes
`remote-backend/<workspace>.tfstate`, so convention 2's `<stack>/<stack>.tfstate` key rule
cannot be reproduced literally. Recorded in `gotchas-and-conventions.md`.

Validate run 1: `Success!` (provider 8.2.0 installed on init).

## Stack 01-networking (18:55:25 → 18:56:14, 1 validate run)

Spec: `aws/terraform/01-networking`. This is where the two clouds disagree most, and the
translation table is in the stack README. Summary: four subnets became one regional subnet
with two secondary ranges (GKE pods/services); the internet gateway disappeared (default
route); EIP + NAT gateway became Cloud Router + Cloud NAT; the two route tables and four
associations disappeared (Cloud NAT applies to the subnet); AZ placement moved to the GKE
stack's `node_locations`. Ten resources became four.

What stayed identical: the file-per-resource layout (`vpc.tf`, `subnetwork.tf`,
`cloud-router.tf`, `cloud-nat.tf`), the single `vpc` object with inline defaults, `main` for
the network and `this` for singletons, `outputs.tf` exposing whole objects plus the two
range names downstream needs, the README's Provides/Consumes.

One convention edge: `secondary_ip_range` is a nested block list, and nested blocks cannot
use `count`; it needs `dynamic` + `for_each`. Convention 6's "count for plurals" is a rule
about resources, and now says so.

Validate run 1: `Success!`.

## Stack 02-gke (18:56:14 → 18:56:29, 2 runs: fmt fail, then green)

Spec: `aws/terraform/02-eks`. Read `01-networking/outputs.tf` first (`network`,
`subnetwork`, `pods_range_name`, `services_range_name`), then `datasources.tf` with
`backend = "gcs"`, `workspace = terraform.workspace`, `config = { bucket, prefix }`.

Translation highlights (full table in the README): the cluster IAM role has no GCP
counterpart (Google-managed service agent); the node IAM role became a dedicated
`google_service_account.node` with four project roles via `count`; `access_config` +
access entry have no counterpart (project IAM authorises); `desired_size = 2` became
`node_count = 1` per zone × 2 `node_locations`; `AL2023_ARM_64_STANDARD` became nothing
(Container-Optimized OS is the default); Workload Identity (`workload_identity_config` +
`GKE_METADATA`) is on, which the AWS stack left for a later add-ons stack. Private nodes,
public endpoint, `deletion_protection = false` explicit (the provider defaults it to true).

Run 1: `terraform fmt -check` **failed** (alignment after `node_service_account_roles`, the
longest attribute name in the object). In a live session the PostToolUse hook formats the
file before validate; here the fix was `terraform fmt`. Validate: `Success!` on both runs.

## Stack 03-data (18:57:13 → 18:57:55, 1 validate run)

Spec: `aws/terraform/03-data`. The subnet group + security group pair became Private
Services Access (`google_compute_global_address` + `google_service_networking_connection`)
and `ipv4_enabled = false`; there is no firewall object because the peering is the
boundary. `manage_master_user_password` became IAM database authentication: a dedicated
`google_service_account.app`, `roles/cloudsql.instanceUser`, and a `google_sql_user` of
type `CLOUD_IAM_SERVICE_ACCOUNT` (name = email minus `.gserviceaccount.com`, per the
provider doc). No password anywhere.

The one thing the docs caught that memory would not: `POSTGRES_18` defaults to the
`ENTERPRISE_PLUS` edition, which rejects `db-f1-micro` at create time. `edition =
"ENTERPRISE"` is explicit in the `sql` object with the reason in a comment. The AWS stack
had no equivalent trap.

Validate run 1: `Success!`.

## The plan-only identity (`iam/plan-only-role.md`)

Same finding as AWS, same two exits. GCS needs Storage Object Admin per the backend doc; a
viewer-only account cannot create the lock object. Shipped: `roles/viewer` +
`roles/storage.objectViewer` + `roles/storage.objectUser` restricted by an IAM condition
`resource.name.endsWith(".tflock")` (uniform bucket-level access is on, which conditions
require). Alternative: `-lock=false`. The AWS answer is `PutObject/DeleteObject` on
`*.tflock`; the GCP answer is a conditional binding. Same shape, different syntax.

## Iterations and blockers

| Stack | validate runs to green | What failed | Fix |
|---|---|---|---|
| 00-remote-backend | 1 | — | — |
| 01-networking | 1 | — | — |
| 02-gke | 2 | `terraform fmt -check` | `terraform fmt` |
| 03-data | 1 | — | — |

Hooks (19:14): testing the GCP-flavor `stop-verify.sh` against the clean `gcp/` tree
returned `decision: block` ("credential-looking material found"). The culprit was the hook
itself: the GCP secret patterns (`"type": "service_account"`, `"private_key_id"`) are
literal strings and match their own source file, while the AWS patterns are regexes that
do not. Fix: `--exclude-dir=hooks` on the grep, applied to both flavors; clean trees
approve, a planted service account key JSON (GCP) and an `AKIA…` key (AWS) block. A
false positive the AWS act could not have surfaced.

Not executed: `terraform plan`, `/infracost:scan`, `terraform apply`. Same reasons as Act 1.

## What the translation cost, against the original

Act 1 (pack install, hooks, four stacks, IAM policy): 18:36:04 → 18:47:18, 11 min 14 s,
one validate failure. Act 2 (pack flavor, four stacks, IAM doc): 18:50:45 → 18:57:55,
7 min 10 s, one fmt failure. Stack time, on the two bases `measurement.md` keeps apart: the
sum of the four stack intervals is ~4 min 28 s on AWS against 2 min 23 s on GCP (~53%);
first stack start to last stack end, gaps included, is ~7 min 06 s against 3 min 07 s
(~44%). The full table, with lines and resources, is in `measurement.md`. The honest
caveat: Act 1 also paid for every decision Act 2 inherited (fail-closed lookup, `workspace`
on remote_state, POC flags, README shape), and the provider docs for both clouds were
verified up front, before Act 1 started.
