#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f compose/docker-compose.yml ps
curl -sSkI https://portal.rheinblick.test | head -n 10
