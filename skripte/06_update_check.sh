#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f compose/docker-compose.yml pull
docker compose -f compose/docker-compose.yml up -d --build
docker compose -f compose/docker-compose.yml ps
