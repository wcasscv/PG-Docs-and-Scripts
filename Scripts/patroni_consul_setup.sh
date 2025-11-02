#!/bin/bash

# PostgreSQL Patroni + Consul Setup Script (Basic Example)

# --- Variables ---
PG_VERSION=15
PGDATA="/var/lib/postgresql/${PG_VERSION}/main"
NODE_NAME="node1"
NODE_IP="10.0.0.1"
CLUSTER_SCOPE="postgres-cluster"

# --- Install Dependencies ---
sudo apt-get update
sudo apt-get install -y python3-pip postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION curl jq
pip3 install patroni[consul]

# --- Install Consul (Agent Mode) ---
wget https://releases.hashicorp.com/consul/1.15.4/consul_1.15.4_linux_amd64.zip
unzip consul_1.15.4_linux_amd64.zip
sudo mv consul /usr/local/bin/
sudo mkdir -p /etc/consul.d /opt/consul
cat <<EOF | sudo tee /etc/consul.d/consul.json
{
  "datacenter": "dc1",
  "data_dir": "/opt/consul",
  "log_level": "INFO",
  "node_name": "${NODE_NAME}",
  "server": false,
  "bind_addr": "${NODE_IP}",
  "retry_join": ["provider=aws tag_key=Name tag_value=consul-server"]
}
EOF
sudo consul agent -config-dir=/etc/consul.d &

# --- Create Patroni Config ---
sudo mkdir -p /etc/patroni
cat <<EOF | sudo tee /etc/patroni/patroni.yml
scope: ${CLUSTER_SCOPE}
name: ${NODE_NAME}

restapi:
  listen: ${NODE_IP}:8008
  connect_address: ${NODE_IP}:8008

consul:
  host: 127.0.0.1:8500
  register_service: true

postgresql:
  listen: ${NODE_IP}:5432
  connect_address: ${NODE_IP}:5432
  data_dir: ${PGDATA}
  authentication:
    replication:
      username: replicator
      password: replicapass
    superuser:
      username: postgres
      password: postgres
  parameters:
    wal_level: replica
    hot_standby: "on"

tags:
  nofailover: false
  noloadbalance: false
EOF

# --- Launch Patroni ---
echo "To start Patroni, run:"
echo "patroni /etc/patroni/patroni.yml"
