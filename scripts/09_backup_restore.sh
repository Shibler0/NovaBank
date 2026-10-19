#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Utilisez sudo bash scripts/09_backup_restore.sh"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="$ROOT/bankdb_backup.dump"
TEST_DB="bankdb_restore_test"

# Ne pas supprimer accidentellement une base de test qui existait déjà.
if sudo -u postgres psql -At -d postgres -c   "SELECT 1 FROM pg_database WHERE datname = '$TEST_DB'" | grep -q 1; then
  echo "La base $TEST_DB existe déjà : arrêt."
  exit 1
fi

sudo -u postgres pg_dump -Fc bankdb > "$BACKUP"
sudo -u postgres createdb -O bank_owner "$TEST_DB"
trap 'sudo -u postgres dropdb --if-exists "$TEST_DB"' EXIT

sudo -u postgres pg_restore --no-owner -d "$TEST_DB" < "$BACKUP"

ORIGINAL=$(sudo -u postgres psql -At -d bankdb -c "SELECT count(*) FROM core.transactions")
RESTORED=$(sudo -u postgres psql -At -d "$TEST_DB" -c "SELECT count(*) FROM core.transactions")
if [ "$ORIGINAL" != "$RESTORED" ]; then
  echo "Erreur de restauration : $ORIGINAL contre $RESTORED"
  exit 1
fi

echo "Sauvegarde/restauration OK : $ORIGINAL écritures."
