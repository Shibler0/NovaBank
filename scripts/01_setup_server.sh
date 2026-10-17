#!/usr/bin/env bash
set -e

apt update
apt install -y postgresql postgresql-client ufw

ufw allow 22/tcp
ufw allow 5432/tcp
ufw --force enable

cat << EOF > /etc/postgresql/18/main/conf.d/novabank.conf
listen_addresses = 'localhost, 192.168.51.10'
password_encryption = 'scram-sha-256'
EOF

cat << EOF > /etc/postgresql/18/main/pg_hba.conf
local   all             postgres                                peer
host    bankdb          bank_owner      127.0.0.1/32            scram-sha-256
host    bankdb          app_user        127.0.0.1/32            scram-sha-256
host    bankdb          +analysts_group 192.168.51.0/24         scram-sha-256
host    bankdb          +support_group  192.168.51.0/24         scram-sha-256
host    bankdb          +auditors_group 192.168.51.0/24         scram-sha-256
host    all             all             0.0.0.0/0               reject
EOF

systemctl restart postgresql
