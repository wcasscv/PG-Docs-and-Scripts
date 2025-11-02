#!/bin/bash

# PostgreSQL Switchover using Patroni

# Assumes you have curl access to the Patroni REST API

PATRONI_API="http://localhost:8008"

echo "Triggering Patroni switchover..."
curl -s -X POST "${PATRONI_API}/switchover" -H "Content-Type: application/json" -d '{
  "leader": "pg0",
  "candidate": "pg1"
}'

echo "Switchover initiated. Monitoring status..."
sleep 5
curl -s ${PATRONI_API}/cluster | jq
