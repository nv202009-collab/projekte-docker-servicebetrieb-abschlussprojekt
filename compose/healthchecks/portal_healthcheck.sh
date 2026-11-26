#!/bin/sh
set -eu
apache2ctl -t >/dev/null 2>&1
php -r '$fp = @fsockopen("127.0.0.1", 80, $errno, $errstr, 3); if (!$fp) { exit(1); } fclose($fp); exit(0);'
