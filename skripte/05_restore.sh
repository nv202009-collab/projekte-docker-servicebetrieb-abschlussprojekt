#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "Verwendung: $0 <pfad-zur-sql-backup-datei>"
  exit 1
fi
cd "$(dirname "$0")/.."
docker compose -f compose/docker-compose.yml exec -T database \
  sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)"' < "$1"
echo "Restore abgeschlossen aus: $1"
