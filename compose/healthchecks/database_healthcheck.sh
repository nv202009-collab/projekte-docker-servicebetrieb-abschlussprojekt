#!/bin/sh
set -eu
mariadb-admin ping -h localhost -u root -p"$(cat /run/secrets/db_root_password)" --silent
