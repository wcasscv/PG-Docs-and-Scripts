
# Terraform Module: AWS RDS PostgreSQL Parameter Group

resource "aws_db_parameter_group" "postgresql_tuned" {
  name        = "postgresql-tuned"
  family      = "postgres15"
  description = "Custom tuned PostgreSQL parameters for RDS"

  parameter {
    name  = "work_mem"
    value = "16384"
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "262144"
  }

  parameter {
    name  = "shared_buffers"
    value = "4096" # value in 8KB pages
  }

  parameter {
    name  = "effective_cache_size"
    value = "12288"
  }

  parameter {
    name  = "wal_compression"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }
}
