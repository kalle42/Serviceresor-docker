#!/usr/bin/env bash
set -euo pipefail

mkdir -p /app/logs /app/session-runtime

node scheduler.js &

exec node admin-server.js