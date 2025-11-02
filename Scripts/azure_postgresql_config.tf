
# Terraform Module: Azure Database for PostgreSQL Configuration

resource "azurerm_postgresql_configuration" "example" {
  name                = "work_mem"
  resource_group_name = "example-resources"
  server_name         = "example-postgres-server"
  value               = "16384"
}

resource "azurerm_postgresql_configuration" "log_min_duration_statement" {
  name                = "log_min_duration_statement"
  resource_group_name = "example-resources"
  server_name         = "example-postgres-server"
  value               = "1000"
}
