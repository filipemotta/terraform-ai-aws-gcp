# Plan-only IAM role for the production workspace

`terraform-plan-readonly` is the role every stack assumes when `terraform.workspace ==
"production"` (see the `workspace_role_arn` map in each `main.tf`), and the fallback for
any workspace not in the map. It is the hard guardrail: even if the agent tries to apply,
AWS answers `AccessDenied`. The role is built from three pieces:

| Piece | What it is | Why |
|---|---|---|
| `arn:aws:iam::aws:policy/ReadOnlyAccess` | AWS managed policy, attached | Enumerates the read actions of every service (`ec2:Describe*`, `eks:List*`, `s3:Get*`, ...) and is maintained by AWS as services appear. This replaces the hand-written `*:Describe*` / `*:List*` / `*:Get*` list a plan-only role is usually given. |
| `plan-only-state.json` | Customer managed policy, attached | Read on the state bucket, write on the lock file only, explicit deny on every other object write. |
| `plan-only-boundary.json` | Customer managed policy, set as the role's **permissions boundary** | The ceiling. Whatever gets attached to the role later, its effective permissions stay inside this policy. |

## Why not the obvious read-all policy

Two reasons, one per statement.

**The grammar.** IAM's `Action` element is `<service>:<action>`. The documented grammar
(`reference_policies_grammar`, "action_string": "Consists of a service namespace, a colon,
and the name of an action. Action names can include wildcards") and the `Action` element
reference (`reference_policies_elements_action`) allow wildcards in the action name
(`s3:Get*`, `iam:*AccessKey*`), the whole-service form (`s3:*`) and the bare `*`. A wildcard
in the service namespace (`*:Describe*`) is not one of the documented forms, and the obvious
`ReadAllResources` + `DenyEverythingElse` pair is built on exactly that. `ReadOnlyAccess`
says the same thing in the grammar's own words, and AWS keeps it current (v188 on
2026-07-21). Offline linters do not catch this: `parliament` expands `*:Describe*` across
every service it knows and reports nothing; the grammar is the source.

**The lock.** A plain read-only policy grants `GetObject` / `GetObjectVersion` /
`ListBucket` on the state bucket and stops there. With native locking
(`use_lockfile = true`), `terraform plan` acquires a lock by creating `<key>.tflock` and
deletes it when done. The S3 backend documentation lists
`s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the `.tflock` path as required
(https://developer.hashicorp.com/terraform/language/backend/s3, "Permissions Required").
With that policy, `terraform plan` on production fails before it reads a single
resource: `Error acquiring the state lock ... AccessDenied`.

## `plan-only-state.json`

Three statements, in the order the article quotes them:

1. `StateLockFileOnly`: `s3:PutObject` + `s3:DeleteObject` on
   `arn:aws:s3:::<bucket>/*.tflock`. The role can leave the lock marker and nothing else.
   The suffix pattern holds for every stack because the key convention is
   `<stack>/<stack>.tfstate`, so its lock is always `<stack>/<stack>.tfstate.tflock`.
2. `DenyWritesOutsideLockFile`: explicit `Deny` of the same two actions with `NotResource`
   on the `.tflock` pattern. Every S3 object write outside the lock marker is denied even if
   a future policy allows it.
3. `ReadStateBucket`: `s3:ListBucket`, `s3:GetObject`, `s3:GetObjectVersion` on the state
   bucket and its objects. `ReadOnlyAccess` already grants `s3:Get*`/`s3:List*` everywhere;
   this statement keeps the state read explicit and self-contained, so the policy still
   works if the managed policy is swapped for a narrower one.

There is no `DenyEverythingElse`. IAM denies by default whatever no policy allows, and a
`NotAction` list built on `*:Describe*` would have the grammar problem above. The
additional hard deny comes from the boundary.

## `plan-only-boundary.json` (permissions boundary)

A permissions boundary is one managed policy that sets the maximum permissions of the role;
the effective permissions are the intersection of the attached policies and the boundary
(https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html). IAM has
no policy composition: the boundary cannot "include" `ReadOnlyAccess` plus a second policy,
and `ReadOnlyAccess` alone as the boundary would deny the `.tflock` write. So the boundary is
a customer managed policy that enumerates, service by service, the read patterns
`terraform plan` needs for the stacks in this repository, plus the lock write:

```json
{
  "Sid": "ReadOnlyCeiling",
  "Effect": "Allow",
  "Action": [
    "ec2:Describe*", "ec2:Get*",
    "eks:Describe*", "eks:List*",
    "iam:Get*", "iam:List*",
    "rds:Describe*", "rds:List*",
    "s3:Get*", "s3:List*"
  ],
  "Resource": "*"
}
```

plus the same `StateLockFileOnly` statement as the custom policy. `sts:GetCallerIdentity`,
which the provider calls at start-up, needs no permission (STS API reference). When a new
stack brings a new service (e.g. `elasticache`, `route53`), add its `Describe*`/`List*`/
`Get*` to the boundary; until then, the plan of that stack fails closed with `AccessDenied`
on production, which is the safe direction.

Together: `ReadOnlyAccess` grants reads, the custom policy grants the lock and denies other
writes, the boundary caps everything. Attaching `PowerUserAccess` to the role by mistake
changes nothing.

## Creating the role (human, once, with `iam:*` on the account)

```bash
ACCOUNT=123456789012

aws iam create-policy --policy-name terraform-plan-only-state \
  --policy-document file://plan-only-state.json
aws iam create-policy --policy-name terraform-plan-only-boundary \
  --policy-document file://plan-only-boundary.json

aws iam create-role --role-name terraform-plan-readonly \
  --assume-role-policy-document file://trust-policy.json \
  --permissions-boundary "arn:aws:iam::${ACCOUNT}:policy/terraform-plan-only-boundary"

aws iam attach-role-policy --role-name terraform-plan-readonly \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam attach-role-policy --role-name terraform-plan-readonly \
  --policy-arn "arn:aws:iam::${ACCOUNT}:policy/terraform-plan-only-state"
```

`trust-policy.json` is the account's own trust policy (which principals may assume the
role); it is environment-specific and not shipped here. The counterpart `terraform-apply`
role (used on `sandbox`/`staging`, and by humans with MFA or CI with required reviewers on
production) is likewise not shipped.

## The second exit

Keep the plain read-only shape and run `terraform plan -lock=false` on production. Simpler,
but the plan runs unlocked and a concurrent apply can make it stale. This repository ships
the lock exception instead, because locking is what keeps a human's apply and the agent's
plan from crossing.

## Verification

- `jq -e .` on both files (part of `validate.sh`).
- Offline lint: `parliament --string "$(cat plan-only-state.json)"` returns no findings;
  `parliament --string "$(cat plan-only-boundary.json)"` returns one LOW, "unnecessary use
  of Resource *", inherent to a read ceiling. Note that `parliament` does not reject the
  `*:Describe*` form; the grammar reference does.
- Live validation, when credentials exist:
  `aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY --policy-document file://plan-only-state.json`
  (and the boundary). Pending until a session has credentials.
- Plan-only smoke test: `terraform workspace select production && terraform plan` succeeds;
  `terraform apply` fails with `AccessDenied`.
