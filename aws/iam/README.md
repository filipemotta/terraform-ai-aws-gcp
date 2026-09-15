# Plan-only IAM policy for the production workspace

`plan-only-policy.json` is attached to the role `terraform-plan-readonly`, the one every
stack assumes when `terraform.workspace == "production"` (see the `workspace_role_arn`
map in each `main.tf`). It is the hard guardrail: even if the agent tries to apply, AWS
answers `AccessDenied`.

## Why this differs from the guide's policy (section 13)

The guide's policy grants only `GetObject` / `GetObjectVersion` / `ListBucket` on the state
bucket. With the S3 backend's native locking (`use_lockfile = true`), `terraform plan`
acquires a lock by creating `<key>.tflock` and deletes it when done. The backend
documentation lists `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the `.tflock`
path as required (https://developer.hashicorp.com/terraform/language/backend/s3,
"Permissions Required"). With the original policy, `terraform plan` on production fails
before it reads a single resource: `Error acquiring the state lock ... AccessDenied`.

Two ways out:

1. **This policy**: allow `s3:PutObject` + `s3:DeleteObject` only on
   `arn:aws:s3:::<bucket>/*.tflock` (`StateLockFileOnly`) and explicitly deny both actions
   on every other key (`DenyWritesOutsideLockFile`). The role can still not write state,
   only the lock marker. This keeps locking on, which matters when humans and CI plan
   against the same state.
2. **Keep the guide's policy** and run `terraform plan -lock=false` on production. Simpler,
   but the plan runs unlocked and a concurrent apply can make it stale.

We ship option 1. The `.tflock` suffix pattern also constrains any future stack because the
key convention is `<stack>/<stack>.tfstate`, so its lock is always `<stack>/<stack>.tfstate.tflock`.

## Verification

- Offline lint: `parliament --string "$(cat plan-only-policy.json)"` (only a LOW finding,
  "unnecessary use of Resource *", inherent to a read-all policy).
- Live validation, when credentials exist:
  `aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY --policy-document file://plan-only-policy.json`.
