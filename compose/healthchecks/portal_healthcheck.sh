#!/bin/sh
set -eu
curl -fsS http://localhost:80/wp-admin/install.php >/dev/null 2>&1 || curl -fsS http://localhost:80/ >/dev/null 2>&1
