#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Lancez ce script avec sudo."
  exit 1
fi

apt-get update
apt-get install -y postgresql postgresql-client ufw

# Réseau privé hôte : à adapter à l'adresse de votre VM.
DB_HOST_IP="${DB_HOST_IP:-192.168.51.10}"
DB_SUBNET="${DB_SUBNET:-192.168.51.0/24}"
PG_VERSION=$(pg_lsclusters --no-header | awk 'NR == 1 {print $1}')
PG_CLUSTER=$(pg_lsclusters --no-header | awk 'NR == 1 {print $2}')
CONF_DIR="/etc/postgresql/$PG_VERSION/$PG_CLUSTER"

if [ ! -d "$CONF_DIR" ]; then
  echo "Cluster PostgreSQL introuvable."
  exit 1
fi

mkdir -p "$CONF_DIR/conf.d"
cat > "$CONF_DIR/conf.d/novabank.conf" <<EOF
listen_addresses = 'localhost,$DB_HOST_IP'
password_encryption = 'scram-sha-256'
log_connections = on
log_disconnections = on
EOF

# L'administration locale de postgres reste possible avec peer.
cat > "$CONF_DIR/pg_hba.conf" <<EOF
local   all     postgres                        peer
local   all     all                             reject
host    bankdb  bank_owner      127.0.0.1/32    scram-sha-256
host    bankdb  app_user        127.0.0.1/32    scram-sha-256
host    bankdb  +analysts_group $DB_SUBNET     scram-sha-256
host    bankdb  +support_group  $DB_SUBNET     scram-sha-256
host    bankdb  +auditors_group $DB_SUBNET     scram-sha-256
host    all     all             0.0.0.0/0      reject
host    all     all             ::/0           reject
EOF

ufw allow 22/tcp
ufw allow from "$DB_SUBNET" to any port 5432 proto tcp
ufw --force enable
systemctl restart postgresql
echo "PostgreSQL prêt (cluster $PG_VERSION/$PG_CLUSTER)."
