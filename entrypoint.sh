#!/usr/bin/env bash
set -euo pipefail

mkdir -p /app/logs /app/session-runtime

echo "0 5 * * * /app/run-daily-trips.sh" | crontab -

cron

exec node admin-server.js