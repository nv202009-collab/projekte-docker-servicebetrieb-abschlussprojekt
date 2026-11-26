#!/usr/bin/env bash
# Zweck: Geordneter Stop oder Entfernen der Container ohne automatische Volumeloeschung
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-26
# Voraussetzungen: Laufender Docker Stack
# Beispielaufruf: ./skripte/02_stack_stop.sh [--remove]

set -euo pipefail # Beendet das Skript bei Fehlern, nicht gesetzten Variablen oder Fehlern in Pipelines

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # Bestimmt das Projektverzeichnis basierend auf dem Speicherort des Skripts
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml" # Pfad zur Docker Compose-Datei
ENV_FILE="$PROJECT_DIR/compose/.env" # Pfad zur Umgebungsvariablen-Datei
LOG_FILE="$PROJECT_DIR/logs/02_stack_stop.log" # Pfad zur Log-Datei

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then # Prueft, ob die Hilfeoption aufgerufen wurde
  echo "Verwendung: $0 [--remove]" # Gibt die Verwendung des Skripts aus
  echo "  Ohne Option: Stoppt alle Stack-Container geordnet (docker compose stop)." # Gibt die Standardaktion des Skripts aus
  echo "  --remove:    Entfernt Container und Netzwerke nach Bestaetigung (Volumes bleiben erhalten!)." # Gibt die Aktion zum Entfernen der Container und Netzwerke aus
  exit 0 # Beendet das Skript nach der Anzeige der Hilfe
fi # Ist die Hilfeoption nicht aufgerufen, wird das Skript fortgesetzt

mkdir -p "$PROJECT_DIR/logs" # Erstellt das Log-Verzeichnis, falls es nicht existiert
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; } # Funktion zum Protokollieren von Nachrichten mit Zeitstempel

if [[ "${1:-}" == "--remove" ]]; then # Prueft, ob die Option zum Entfernen der Container und Netzwerke aufgerufen wurde
  read -r -p "Container und Netzwerke wirklich entfernen? Volumes bleiben erhalten [ja/NEIN]: " CONFIRM # Fordert den Benutzer zur Bestätigung auf
  if [[ "$CONFIRM" != "ja" ]]; then # Prueft, ob die Bestätigung nicht "ja" ist
    log "Abbruch durch Benutzer." # Protokolliert den Abbruch durch den Benutzer
    exit 1 # Beendet das Skript, wenn die Bestätigung nicht "ja" ist
  fi # Ist die Bestätigung "ja", wird der Container und das Netzwerk entfernt
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down # Entfernt die Container und Netzwerke, aber behält Volumes, Backups und Zertifikate bei
  log "Container und Netzwerke entfernt (Volumes, Backups und Zertifikate unveraendert)." # Protokolliert die erfolgreiche Entfernung der Container und Netzwerke
else # Wenn die Option zum Entfernen der Container und Netzwerke nicht aufgerufen wurde, wird der Stack geordnet gestoppt
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" stop # Stoppt die Container geordnet
  log "Stack geordnet gestoppt." # Protokolliert den erfolgreichen geordneten Stopp des Stacks
fi # Ist die Option zum Entfernen der Container und Netzwerke nicht aufgerufen, wird der Stack geordnet gestoppt

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -a | tee -a "$LOG_FILE" # Listet alle Container auf, die gestoppt oder entfernt wurden, und protokolliert die Ausgabe in der Log-Datei
