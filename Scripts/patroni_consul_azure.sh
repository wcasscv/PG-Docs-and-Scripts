#!/bin/bash
# Patroni + Consul on AWS EC2 with cloud auto-discovery

# Assumes EC2 instance role has proper permissions and instance tagging is used
NODE_NAME=azure-node-$(hostname)
NODE_IP=$(hostname -I | awk '{print $1}')
CLUSTER_SCOPE="aws-postgres-cluster"
PG_VERSION=15
PGDATA="/var/lib/postgresql/${PG_VERSION}/main"

# Install packages
sudo apt-get update
sudo apt-get install -y python3-pip postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION unzip curl jq
pip3 install patroni[consul]

# Install Consul with AWS auto-join
wget https://releases.hashicorp.com/consul/1.15.4/consul_1.15.4_linux_amd64.zip
unzip consul_1.15.4_linux_amd64.zip
sudo mv consul /usr/local/bin/
sudo mkdir -p /etc/consul.d /opt/consul
cat <<EOF | sudo tee /etc/consul.d/consul.json
{
  "datacenter": "aws-dc",
  "data_dir": "/opt/consul",
  "log_level": "INFO",
  "node_name": "${NODE_NAME}",
  "server": false,
  "bind_addr": "${NODE_IP}",
  "retry_join": ["10.0.0.5 10.0.0.6"]
}
EOF
consul agent -config-dir=/etc/consul.d &

# Patroni Config
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
EOF

echo "Run Patroni using:"
echo "patroni /etc/patroni/patroni.yml"
