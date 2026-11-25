#!/usr/bin/env bash
# Zweck: Geordneter Stop oder Entfernen der Container ohne automatische Volumeloeschung
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-25
# Voraussetzungen: Laufender Docker Stack
# Beispielaufruf: ./skripte/02_stack_stop.sh [--remove]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
LOG_FILE="$PROJECT_DIR/logs/02_stack_stop.log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Verwendung: $0 [--remove]"
  echo "  Ohne Option: Stoppt alle Stack-Container geordnet (docker compose stop)."
  echo "  --remove:    Entfernt Container und Netzwerke nach Bestaetigung (Volumes bleiben erhalten!)."
  exit 0
fi

mkdir -p "$PROJECT_DIR/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

if [[ "${1:-}" == "--remove" ]]; then
  read -r -p "Container und Netzwerke wirklich entfernen? Volumes bleiben erhalten [ja/NEIN]: " CONFIRM
  if [[ "$CONFIRM" != "ja" ]]; then
    log "Abbruch durch Benutzer."
    exit 1
  fi
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
  log "Container und Netzwerke entfernt (Volumes, Backups und Zertifikate unveraendert)."
else
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" stop
  log "Stack geordnet gestoppt."
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -a | tee -a "$LOG_FILE"
