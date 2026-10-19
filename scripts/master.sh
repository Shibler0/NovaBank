#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Utilisez sudo bash scripts/master.sh"
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/01_setup_server.sh"

echo "ATTENTION : la base bankdb sera supprimée et reconstruite."
read -r -p "Tapez OUI pour continuer : " CONFIRM
if [ "$CONFIRM" != "OUI" ]; then
  echo "Annulé."
  exit 0
fi

# Suppression avant recréation. On conserve les autres bases PostgreSQL.
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS bankdb WITH (FORCE);"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "
DROP ROLE IF EXISTS analyst_user, support_user, auditor_user, app_user;
DROP ROLE IF EXISTS analysts_group, support_group, auditors_group, bank_owner;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE ROLE bank_owner LOGIN;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE bankdb OWNER bank_owner;"

# Les objets SQL appartiennent à bank_owner et non à postgres.
run_owner() {
  (printf 'SET ROLE bank_owner;\n'; cat "$DIR/$1") |
    sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d bankdb
}
run_admin() {
  sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d bankdb < "$DIR/$1"
}

run_owner 02_schema_and_data.sql
run_admin 03_roles_and_permissions.sql
run_owner 04_views.sql
run_owner 05_indexes_and_perf.sql
run_owner 06_triggers.sql
run_owner 07_procedures.sql
run_admin 08_tests.sql
"$DIR/09_backup_restore.sh"

echo "NovaBank installé et tests terminés."
