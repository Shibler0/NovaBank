#!/usr/bin/env bash
set -e

sudo -u postgres psql -c "DROP DATABASE IF EXISTS bankdb;"
sudo -u postgres psql -c "DROP ROLE IF EXISTS app_user, analysts_group, support_group, auditors_group, bank_owner;"

./01_setup_server.sh
sudo -u postgres psql -c "CREATE DATABASE bankdb;"
sudo -u postgres psql -d bankdb < 02_schema_and_data.sql
sudo -u postgres psql -d bankdb < 03_roles_and_permissions.sql
sudo -u postgres psql -d bankdb < 04_views.sql
sudo -u postgres psql -d bankdb < 05_indexes_and_perf.sql
sudo -u postgres psql -d bankdb < 06_triggers.sql
sudo -u postgres psql -d bankdb < 07_procedures.sql
