#!/usr/bin/env bash
# Zweck: Konsistente Sicherung von MariaDB, Volumes, Konfiguration und Zertifikats-Metadaten inkl. SHA256
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-26
# Voraussetzungen: Laufender database-Container, mindestens 500 MB freier Speicher
# Beispielaufruf: ./skripte/03_backup.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR="$PROJECT_DIR/backups/backup_$TS"
LOG_FILE="$PROJECT_DIR/logs/03_backup.log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Verwendung: $0 [--help]"
  echo "Erstellt ein vollstaendiges Backup mit Zeitstempel und SHA256-Pruefsumme unter backups/."
  exit 0
fi

mkdir -p "$BACKUP_DIR" "$PROJECT_DIR/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

FREE_KB=$(df -k "$PROJECT_DIR/backups" | awk 'NR==2 {print $4}')
if [[ "$FREE_KB" -lt 512000 ]]; then
  log "FEHLER: Weniger als 500 MB freier Speicher verfuegbar."
  exit 1
fi

log "Starte Backup in $BACKUP_DIR..."

# 1. Konsistenter MariaDB-Dump (Kennwort wird sicher im Container aus Docker Secret gelesen)
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T database \
  sh -c 'mariadb-dump -u root -p"$(cat /run/secrets/db_root_password)" --single-transaction --databases "$MARIADB_DATABASE"' \
  > "$BACKUP_DIR/rheinblick_portal.sql"
log "Datenbank-Dump erfolgreich erstellt."

# 2. Persistentes WordPress-Volume (portal_data) sichern
docker run --rm \
  -v rheinblick-portal_portal_data:/source:ro \
  -v "$BACKUP_DIR":/backup \
  alpine:3.20 tar -czf /backup/portal_data.tar.gz -C /source .
log "Anwendungsdaten (portal_data) gesichert."

# 3. Compose-, Nginx- und Zertifikats-Konfiguration sichern (ohne private Schluessel/Klartext-Secrets)
tar -czf "$BACKUP_DIR/konfiguration.tar.gz" \
  -C "$PROJECT_DIR" \
  compose/docker-compose.yml compose/.env.example compose/nginx compose/healthchecks \
  zertifikate/ca/rheinblick-ca.crt zertifikate/server/portal.rheinblick.test.crt
log "Konfigurations- und oeffentliche Zertifikatsdateien gesichert."

# 4. SHA256-Pruefsummen erzeugen
(cd "$BACKUP_DIR" && sha256sum rheinblick_portal.sql portal_data.tar.gz konfiguration.tar.gz > SHA256SUMS.txt)
log "SHA256-Pruefsummen erstellt. Backup abgeschlossen: $BACKUP_DIR"
