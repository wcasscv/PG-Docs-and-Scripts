#!/bin/bash

# PostgreSQL Switchover using repmgr

echo "Checking cluster status..."
repmgr cluster show

echo "Performing switchover from primary to standby..."
repmgr standby switchover --force

echo "Switchover complete. Verifying cluster state..."
repmgr cluster show
