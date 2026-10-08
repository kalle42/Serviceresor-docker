#!/usr/bin/env bash
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd)"
USER_ID="$1"
URL="$2"
TIME="$3"
MINUTES="$4"
LOG_TIME="${TIME//:/}"

cd "$PROJECT"

exec node tracking-service.js track "$USER_ID" "$URL" "$TIME" "$MINUTES" \
    2>&1 | tee -a "trip-${LOG_TIME}.log"