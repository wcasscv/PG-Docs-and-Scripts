
#!/bin/bash
# Setup script for PostgreSQL Prometheus Exporter on macOS

# 1. Ensure Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Please install Homebrew first: https://brew.sh/"
  exit 1
fi

# 2. Install postgres_exporter via brew
brew install prometheus-postgres-exporter

# 3. Create postgres_exporter user and grant required permissions
psql -U postgres -c "CREATE USER exporter WITH PASSWORD 'password';"
psql -U postgres -c "GRANT CONNECT ON DATABASE postgres TO exporter;"
psql -U postgres -c "GRANT pg_monitor TO exporter;"

# 4. Configure environment variable
echo 'export DATA_SOURCE_NAME="postgresql://exporter:password@localhost:5432/postgres?sslmode=disable"' >> ~/.zprofile
source ~/.zprofile

# 5. Start the exporter manually or via launchctl
echo "You can start the exporter using:"
echo "  DATA_SOURCE_NAME=postgresql://exporter:password@localhost:5432/postgres prometheus-postgres-exporter"

echo "To run on startup, consider creating a launch agent or using a tool like launchd."
