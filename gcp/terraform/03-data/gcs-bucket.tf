resource "google_storage_bucket" "this" {
  name                        = var.app_bucket.name
  location                    = var.app_bucket.location
  storage_class               = var.app_bucket.storage_class
  force_destroy               = var.app_bucket.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
