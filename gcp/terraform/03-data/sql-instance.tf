resource "google_sql_database_instance" "this" {
  name                = var.sql.instance_name
  region              = var.impersonation.region
  database_version    = var.sql.database_version
  deletion_protection = var.sql.deletion_protection

  settings {
    tier                        = var.sql.tier
    edition                     = var.sql.edition
    availability_type           = var.sql.availability_type
    disk_size                   = var.sql.disk_size
    disk_type                   = var.sql.disk_type
    deletion_protection_enabled = var.sql.deletion_protection_in_gcp

    ip_configuration {
      ipv4_enabled    = false
      private_network = local.network_self_link
    }

    backup_configuration {
      enabled = var.sql.backup_enabled
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  # The instance does not interpolate the peering connection; the dependency
  # must be explicit or the private IP allocation fails on first apply.
  depends_on = [google_service_networking_connection.this]
}

resource "google_sql_database" "this" {
  name     = var.sql.database_name
  instance = google_sql_database_instance.this.name
}
