#!/usr/bin/env bash
# Zweck: Kontrollierte Wiederherstellung von Datenbank und Anwendungsdaten aus einem geprueften Backup
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-25
# Voraussetzungen: Gueltiger Backup-Ordner mit SHA256SUMS.txt, laufender database-Container
# Beispielaufruf: ./skripte/04_restore.sh backups/backup_20261125_132000

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
LOG_FILE="$PROJECT_DIR/logs/04_restore.log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  echo "Verwendung: $0 <PFAD_ZUM_BACKUP_ORDNER>"
  echo "Prueft SHA256-Summen, verlangt Bestaetigung und stellt Datenbank + portal_data wieder her."
  exit 0
fi

BACKUP_DIR="$1"
mkdir -p "$PROJECT_DIR/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

if [[ ! -d "$BACKUP_DIR" || ! -f "$BACKUP_DIR/SHA256SUMS.txt" ]]; then
  log "FEHLER: Ungueltiger Backup-Ordner oder fehlende SHA256SUMS.txt: $BACKUP_DIR"
  exit 1
fi

log "Pruefe Integritaet der Backupdateien mittels SHA256..."
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS.txt)
log "Pruefsummen erfolgreich verifiziert."

read -r -p "ACHTUNG: Aktuelle Datenbank und Portal-Daten werden ueberschrieben! Fortfahren? [WIEDERHERSTELLEN]: " CONFIRM
if [[ "$CONFIRM" != "WIEDERHERSTELLEN" ]]; then
  log "Restore durch Benutzer abgebrochen."
  exit 1
fi

log "Stelle MariaDB-Datenbank wieder her..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T database \
  sh -c 'mariadb -u root -p"$(cat /run/secrets/db_root_password)"' < "$BACKUP_DIR/rheinblick_portal.sql"

log "Stelle WordPress-Volume (portal_data) wieder her..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" stop portal
docker run --rm \
  -v rheinblick-portal_portal_data:/target \
  -v "$(cd "$BACKUP_DIR" && pwd)":/backup:ro \
  alpine:3.20 sh -c "rm -rf /target/* && tar -xzf /backup/portal_data.tar.gz -C /target"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" start portal
sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --cacert "$PROJECT_DIR/zertifikate/ca/rheinblick-ca.crt" https://portal.rheinblick.test || echo "000")
log "Restore abgeschlossen. HTTPS-Funktionsnachtest Status: $HTTP_CODE"
