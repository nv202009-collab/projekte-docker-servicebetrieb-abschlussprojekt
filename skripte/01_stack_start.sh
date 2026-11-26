#!/usr/bin/env bash
# Zweck: Vorpruefungen, Compose-Validierung, Stack-Start, Health-Wartezeit und HTTPS-Test
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-26
# Voraussetzungen: Docker Engine, Compose Plugin, compose/.env, compose/secrets/*.txt
# Beispielaufruf: ./skripte/01_stack_start.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
LOG_FILE="$PROJECT_DIR/logs/01_stack_start.log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Verwendung: $0 [--help]"
  echo "Prueft Voraussetzungen, validiert docker-compose.yml, startet den Stack und prueft HTTPS."
  exit 0
fi

mkdir -p "$PROJECT_DIR/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "Starte Vorpruefungen..."
for f in "$COMPOSE_FILE" "$ENV_FILE" \
         "$PROJECT_DIR/compose/secrets/db_root_password.txt" \
         "$PROJECT_DIR/compose/secrets/db_user_password.txt" \
         "$PROJECT_DIR/zertifikate/server/portal.rheinblick.test.crt" \
         "$PROJECT_DIR/zertifikate/server/portal.rheinblick.test.key"; do
  if [[ ! -s "$f" ]]; then
    log "FEHLER: Erforderliche Datei fehlt oder ist leer: $f"
    exit 1
  fi
done

docker info >/dev/null 2>&1 || { log "FEHLER: Docker Daemon nicht erreichbar."; exit 1; }
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config -q
log "Compose-Konfiguration erfolgreich validiert."

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
log "Container gestartet. Warte auf Health-Status (max. 60s)..."

for i in {1..12}; do
  UNHEALTHY=$(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps --format json | grep -v '"Health":"healthy"' || true)
  if [[ -z "$UNHEALTHY" ]]; then
    log "Alle Dienste melden Status 'healthy'."
    break
  fi
  sleep 5
done

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --cacert "$PROJECT_DIR/zertifikate/ca/rheinblick-ca.crt" https://portal.rheinblick.test || echo "000")
if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
  log "HTTPS-Erreichbarkeitstest erfolgreich (HTTP Status: $HTTP_CODE)."
else
  log "FEHLER: HTTPS-Test fehlgeschlagen (HTTP Status: $HTTP_CODE)."
  exit 1
fi
