#!/usr/bin/env bash
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd)"
USER_ID="$1"
URL="$2"
TIME="$3"
LOG_TIME="${TIME//:/}"

cd "$PROJECT"

node tracking-service.js check "$USER_ID" "$URL" "$TIME" \
    2>&1 | tee -a "trip-${LOG_TIME}-status.log"
EXIT_CODE=${PIPESTATUS[0]}

if [ "$EXIT_CODE" -eq 10 ]; then
    echo "Trip cancelled, removing tracking task."
    exit 0
fi

exit "$EXIT_CODE"