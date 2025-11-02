#!/bin/bash

# TLS setup for PostgreSQL and Consul
# Assumes existing certificates and keys in /etc/ssl/certs/custom

# PostgreSQL TLS Configuration
echo "Configuring PostgreSQL for SSL..."
sudo mkdir -p /etc/postgresql/ssl
sudo cp /etc/ssl/certs/custom/server.crt /etc/postgresql/ssl/
sudo cp /etc/ssl/private/custom/server.key /etc/postgresql/ssl/
sudo chmod 600 /etc/postgresql/ssl/server.key

sudo tee -a /etc/postgresql/15/main/postgresql.conf <<EOF
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file = '/etc/postgresql/ssl/server.key'
ssl_ciphers = 'HIGH:!aNULL:!MD5'
EOF

# Reload PostgreSQL
sudo systemctl reload postgresql

# Consul TLS Configuration
echo "Configuring Consul for TLS..."
sudo mkdir -p /etc/consul.d/ssl
sudo cp /etc/ssl/certs/custom/consul-agent-ca.pem /etc/consul.d/ssl/
sudo cp /etc/ssl/certs/custom/dc1-server-consul-0.pem /etc/consul.d/ssl/
sudo cp /etc/ssl/private/custom/dc1-server-consul-0-key.pem /etc/consul.d/ssl/

sudo tee /etc/consul.d/tls.json <<EOF
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "ca_file": "/etc/consul.d/ssl/consul-agent-ca.pem",
  "cert_file": "/etc/consul.d/ssl/dc1-server-consul-0.pem",
  "key_file": "/etc/consul.d/ssl/dc1-server-consul-0-key.pem"
}
EOF

# Restart Consul agent
sudo systemctl restart consul

echo "TLS has been enabled for both PostgreSQL and Consul."
