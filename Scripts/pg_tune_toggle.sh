
#!/bin/bash
# Toggle between OLTP and OLAP configurations

PG_CONF_DIR="/etc/postgresql/15/main"
OLTP_CONF="postgresql_oltp_tuned.conf"
OLAP_CONF="postgresql_olap_tuned.conf"

if [[ "$1" == "oltp" ]]; then
  sudo cp "$OLTP_CONF" "$PG_CONF_DIR/postgresql.conf"
  echo "Switched to OLTP configuration."
elif [[ "$1" == "olap" ]]; then
  sudo cp "$OLAP_CONF" "$PG_CONF_DIR/postgresql.conf"
  echo "Switched to OLAP configuration."
else
  echo "Usage: $0 [oltp|olap]"
fi

sudo systemctl restart postgresql
