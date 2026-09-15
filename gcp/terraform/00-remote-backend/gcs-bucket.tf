# State bucket: versioned, uniform bucket-level access, public access
# prevention enforced. Encryption at rest is on by default (Google-managed).

resource "google_storage_bucket" "this" {
  name                        = var.remote_backend.name
  location                    = var.remote_backend.location
  storage_class               = var.remote_backend.storage_class
  force_destroy               = var.remote_backend.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
