#!/bin/bash

# Patroni + etcd Setup Script

# --- Variables ---
PG_VERSION=15
PGDATA="/var/lib/postgresql/${PG_VERSION}/main"
NODE_NAME="patroni-node"
NODE_IP="$(hostname -I | awk '{print $1}')"
CLUSTER_SCOPE="etcd-postgres-cluster"

# --- Install PostgreSQL and dependencies ---
sudo apt-get update
sudo apt-get install -y python3-pip postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION curl jq etcd

pip3 install patroni[etcd]

# --- Configure etcd ---
sudo mkdir -p /etc/etcd
cat <<EOF | sudo tee /etc/default/etcd
ETCD_LISTEN_PEER_URLS="http://${NODE_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="http://${NODE_IP}:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${NODE_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${NODE_IP}:2379"
ETCD_INITIAL_CLUSTER="default=http://${NODE_IP}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_NAME="${NODE_NAME}"
EOF

sudo systemctl restart etcd

# --- Create Patroni Configuration ---
sudo mkdir -p /etc/patroni
cat <<EOF | sudo tee /etc/patroni/patroni.yml
scope: ${CLUSTER_SCOPE}
name: ${NODE_NAME}

restapi:
  listen: ${NODE_IP}:8008
  connect_address: ${NODE_IP}:8008

etcd:
  host: ${NODE_IP}:2379

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

echo "To start Patroni, run:"
echo "patroni /etc/patroni/patroni.yml"
