#!/usr/bin/env bash
# Zweck: System-, Container-, Health-, Ressourcen- und HTTPS-Zustandsbericht
# Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
# Datum: 2026-11-25
# Voraussetzungen: Docker Engine, curl, laufender Stack
# Beispielaufruf: ./skripte/05_health_report.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/compose/.env"
REPORT_FILE="$PROJECT_DIR/logs/health_report_$(date '+%Y%m%d_%H%M%S').log"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Verwendung: $0 [--help]"
  echo "Erstellt einen vollstaendigen Gesundheits- und Ressourcenbericht unter logs/."
  exit 0
fi

mkdir -p "$PROJECT_DIR/logs"
EXIT_CODE=0

{
  echo "=== RHEINBLICK PORTAL HEALTH REPORT ==="
  echo "Zeitstempel: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "--- 1. Service & Health Status ---"
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
  echo ""
  echo "--- 2. Container CPU & RAM Auslastung ---"
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
  echo ""
  echo "--- 3. Host Speicher & Docker Volumes ---"
  df -h "$PROJECT_DIR"
  docker system df
  echo ""
  echo "--- 4. HTTPS Erreichbarkeitstest ---"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --cacert "$PROJECT_DIR/zertifikate/ca/rheinblick-ca.crt" https://portal.rheinblick.test || echo "000")
  echo "HTTPS Status Code: $HTTP_CODE"
  if [[ ! "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    echo "WARNUNG: HTTPS nicht erreichbar!"
    EXIT_CODE=1
  fi
} | tee "$REPORT_FILE"

exit $EXIT_CODE
