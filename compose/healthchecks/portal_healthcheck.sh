#!/bin/sh
set -eu
php -r '
$ctx = stream_context_create(["http" => ["timeout" => 5, "follow_location" => 1]]);
$res = @file_get_contents("http://127.0.0.1:80/", false, $ctx);
exit($res !== false ? 0 : 1);
'
