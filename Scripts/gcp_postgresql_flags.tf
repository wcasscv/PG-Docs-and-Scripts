
# Terraform Module: GCP Cloud SQL PostgreSQL Settings

resource "google_sql_database_instance" "postgres_instance" {
  name = "pg-instance"
  database_version = "POSTGRES_15"
  region = "us-central1"

  settings {
    tier = "db-custom-2-7680"

    database_flags {
      name  = "work_mem"
      value = "16384"
    }

    database_flags {
      name  = "maintenance_work_mem"
      value = "262144"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
  }
}
