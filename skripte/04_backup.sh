#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p backups
docker compose -f compose/docker-compose.yml exec -T database \
  sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/db_root_password)" --all-databases' > "backups/db_${TS}.sql"
tar -czf "backups/wp_${TS}.tar.gz" zertifikate/ca compose/.env
echo "Backup erstellt: backups/db_${TS}.sql und backups/wp_${TS}.tar.gz"
