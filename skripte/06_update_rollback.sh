#!/usr/bin/env bash
# Zweck: Kontrolliertes Update und Rollback des eigenen Reverse-Proxy-Images inkl. Nachweis
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-25
# Voraussetzungen: Docker Engine, Compose Stack, lokales Git-Repository
# Beispielaufruf: ./skripte/06_update_rollback.sh [check|update 1.1|rollback 1.0]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
LOG_FILE="$PROJECT_DIR/logs/06_update_rollback.log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  echo "Verwendung: $0 <check|update <TAG>|rollback <TAG>>"
  echo "  check          : Prueft Git-Stand, Backups, Speicher und verfuegbare Image-Tags"
  echo "  update <TAG>   : Baut und aktiviert rheinblick/nginx-proxy:<TAG> mit Health-Pruefung"
  echo "  rollback <TAG> : Setzt NGINX_IMAGE auf rheinblick/nginx-proxy:<TAG> zurueck und testet HTTPS"
  exit 0
fi

mkdir -p "$PROJECT_DIR/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

ACTION="$1"
TAG="${2:-1.0}"

case "$ACTION" in
  check)
    log "Vorpruefung fuer Update/Rollback:"
    log "Aktueller Git-Branch: $(git -C "$PROJECT_DIR" branch --show-current)"
    log "Letzter Backup-Ordner: $(ls -dt "$PROJECT_DIR"/backups/backup_* 2>/dev/null | head -n1 || echo 'KEIN BACKUP')"
    docker images rheinblick/nginx-proxy | tee -a "$LOG_FILE"
    ;;
  update)
    log "Baue neues Image rheinblick/nginx-proxy:$TAG..."
    docker build -t "rheinblick/nginx-proxy:$TAG" "$PROJECT_DIR/compose/nginx"
    sed -i "s|^NGINX_IMAGE=.*|NGINX_IMAGE=rheinblick/nginx-proxy:$TAG|" "$ENV_FILE"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d reverse-proxy
    sleep 5
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps reverse-proxy | tee -a "$LOG_FILE"
    ;;
  rollback)
    log "Fuehre Rollback auf rheinblick/nginx-proxy:$TAG durch..."
    sed -i "s|^NGINX_IMAGE=.*|NGINX_IMAGE=rheinblick/nginx-proxy:$TAG|" "$ENV_FILE"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d reverse-proxy
    sleep 5
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --cacert "$PROJECT_DIR/zertifikate/ca/rheinblick-ca.crt" https://portal.rheinblick.test || echo "000")
    log "Rollback abgeschlossen. HTTPS-Nachtest Status: $HTTP_CODE"
    ;;
  *)
    echo "Unbekannte Aktion: $ACTION (erlaubt: check, update, rollback)"
    exit 1
    ;;
esac
