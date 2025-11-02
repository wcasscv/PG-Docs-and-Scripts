
#!/bin/bash
# Setup script for PostgreSQL Prometheus Exporter

# 1. Create postgres_exporter user
sudo -u postgres psql -c "CREATE USER exporter WITH PASSWORD 'password';"
sudo -u postgres psql -c "GRANT CONNECT ON DATABASE postgres TO exporter;"
sudo -u postgres psql -c "GRANT pg_monitor TO exporter;"

# 2. Download binary
wget https://github.com/prometheus-community/postgres_exporter/releases/latest/download/postgres_exporter-linux-amd64.tar.gz
tar -xzf postgres_exporter-linux-amd64.tar.gz
sudo mv postgres_exporter /usr/local/bin/

# 3. Create systemd service
sudo cp postgres_exporter.service /etc/systemd/system/postgres_exporter.service

# 4. Start and enable
sudo systemctl daemon-reexec
sudo systemctl enable postgres_exporter
sudo systemctl start postgres_exporter
