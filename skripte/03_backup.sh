#!/usr/bin/env bash
# Zweck: Konsistente Sicherung von MariaDB, Volumes, Konfiguration und Zertifikats-Metadaten inkl. SHA256
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-25
# Voraussetzungen: Laufender database-Container, mindestens 500 MB freier Speicher
# Beispielaufruf: ./skripte/03_backup.sh

set -euo pipefail # Skript bricht bei Fehlern ab, keine uninitialisierten Variablen, Fehler in Pipes werden erkannt

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # Absoluter Pfad zum Projektverzeichnis
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml" # Absoluter Pfad zur Docker-Compose-Datei
ENV_FILE="$PROJECT_DIR/compose/.env" # Absoluter Pfad zur .env-Datei
TS="$(date '+%Y%m%d_%H%M%S')" # Zeitstempel fuer das Backup-Verzeichnis
BACKUP_DIR="$PROJECT_DIR/backups/backup_$TS" # Absoluter Pfad zum Backup-Verzeichnis mit Zeitstempel
LOG_FILE="$PROJECT_DIR/logs/03_backup.log" # Absoluter Pfad zur Log-Datei

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then # Hilfetext anzeigen
  echo "Verwendung: $0 [--help]" # Informationen zur Verwendung des Skripts
  echo "Erstellt ein vollstaendiges Backup mit Zeitstempel und SHA256-Pruefsumme unter backups/." # Beschreibung des Backup-Prozesses
  exit 0 # Skript beenden
fi # If-Abfrage Ende

mkdir -p "$BACKUP_DIR" "$PROJECT_DIR/logs" # Log- und Backup-Verzeichnisse erstellen, falls sie nicht existieren
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; } # Log-Funktion, die Zeitstempel hinzufügt und sowohl in die Log-Datei als auch auf die Konsole schreibt

FREE_KB=$(df -k "$PROJECT_DIR/backups" | awk 'NR==2 {print $4}') # Freien Speicherplatz in KB im Backup-Verzeichnis ermitteln
if [[ "$FREE_KB" -lt 512000 ]]; then # Weniger als 500 MB freier Speicherplatz
  log "FEHLER: Weniger als 500 MB freier Speicher verfuegbar." # Fehlermeldung ausgeben
  exit 1 # Skript mit Fehlercode 1 beenden
fi # If-Abfrage Ende

log "Starte Backup in $BACKUP_DIR..." # Log-Nachricht ausgeben, dass das Backup gestartet wird

# 1. Konsistenter MariaDB-Dump (Kennwort wird sicher im Container aus Docker Secret gelesen)
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T database \  #Fuehrt den Befehl im laufenden Datenbank-Container ohne TTY aus
  sh -c 'mariadb-dump -u root -p"$(cat /run/secrets/db_root_password)" --single-transaction --databases "$MARIADB_DATABASE"' \   #Liest das Root-Kennwort sicher aus dem Docker Secret (kein Klartext im Skript)
  > "$BACKUP_DIR/rheinblick_portal.sql"  
log "Datenbank-Dump erfolgreich erstellt."

# 2. Persistentes WordPress-Volume (portal_data) sichern
docker run --rm \  # 
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
