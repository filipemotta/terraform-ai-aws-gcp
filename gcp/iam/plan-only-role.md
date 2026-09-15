# Plan-only service account for the production workspace

`terraform-plan@atlas-demo-123.iam.gserviceaccount.com` is the identity every stack
impersonates when `terraform.workspace == "production"` (see the `workspace_service_account`
map in each `main.tf`). It is the hard guardrail: even if the agent tries to apply, the
Google API answers `403 PERMISSION_DENIED`. Its counterpart `terraform-apply@...` is
impersonated on `sandbox` and `staging` and by humans/CI for production applies.

## Bindings

| Scope                       | Role                                | Why                                                                 |
|-----------------------------|-------------------------------------|---------------------------------------------------------------------|
| project `atlas-demo-123`    | `roles/viewer`                      | Read every resource `terraform plan` refreshes. Basic role, but read-only by definition; Google warns basic roles are broad, so scope a custom role if compliance requires it. |
| bucket `atlas-us-central1-bucket-terraform-state` | `roles/storage.objectViewer` | Read `<prefix>/<workspace>.tfstate` (`storage.objects.get` + `list`). |
| bucket, conditional         | `roles/storage.objectUser` with condition `resource.name.endsWith(".tflock")` | Create/delete the lock object only. See "The lock problem". |
| service account `terraform-plan@...` | `roles/iam.serviceAccountTokenCreator` granted to the humans / CI principal | Required to impersonate (`impersonate_service_account`). |

Nothing grants `roles/editor`, `roles/owner`, or any `*.create` / `*.delete` on project
resources. `gcloud` equivalent (run once by a human with `roles/resourcemanager.projectIamAdmin`):

```bash
PROJECT=atlas-demo-123
BUCKET=atlas-us-central1-bucket-terraform-state
SA=terraform-plan@${PROJECT}.iam.gserviceaccount.com

gcloud iam service-accounts create terraform-plan --project "$PROJECT" \
  --display-name "Terraform plan-only (production)"
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member "serviceAccount:$SA" --role roles/viewer
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" \
  --member "serviceAccount:$SA" --role roles/storage.objectViewer
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" \
  --member "serviceAccount:$SA" --role roles/storage.objectUser \
  --condition 'expression=resource.name.endsWith(".tflock"),title=tflock-only'
```

## The lock problem (same finding as on AWS)

The GCS backend locks natively and the documentation asks for Storage Object Admin on the
bucket (https://developer.hashicorp.com/terraform/language/backend/gcs). A viewer-only
account can read state but cannot create the lock object, so `terraform plan` fails at
lock acquisition, before the first API read. Two ways out, mirroring `../../aws/iam/`:

1. **Conditional write** (shipped above): `roles/storage.objectUser` (create, get, list,
   delete, update on objects; no `setIamPolicy`) restricted by an IAM condition to object
   names ending in `.tflock`. State objects (`<prefix>/<workspace>.tfstate`) stay read-only.
   Locking stays on, which matters when humans and CI plan against the same state.
2. **`terraform plan -lock=false`** on production with the viewer-only account. Simpler,
   but the plan runs unlocked and a concurrent apply can make it stale.

When the backend itself impersonates the account (`GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT`
or `impersonate_service_account` in the backend block), the bucket bindings above are what
the backend uses. When the backend runs with the caller's own ADC credentials, the caller
needs them instead, and the plan-only account only governs provider API calls.

## What this is not

Not an org policy and not VPC Service Controls. Pair it with an organization policy that
forbids service account key creation (`iam.disableServiceAccountKeyCreation`) so the
guardrail cannot be bypassed with an exported key.

## Verification

- `gcloud projects get-iam-policy atlas-demo-123 --flatten="bindings[].members" --filter="bindings.members:terraform-plan@" --format="table(bindings.role)"` should list only `roles/viewer`.
- `gcloud storage buckets get-iam-policy gs://atlas-us-central1-bucket-terraform-state` should show the conditional `objectUser` binding.
- Plan-only smoke test: `terraform workspace select production && terraform plan` succeeds; `terraform apply` fails with `PERMISSION_DENIED`.
