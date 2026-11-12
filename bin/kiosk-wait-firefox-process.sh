#!/bin/bash
# Attend le processus Firefox kiosque (sans -remote / ping : plante sur Pi 5).
set -uo pipefail
TRIES="${1:-30}"
SLEEP="${2:-2}"
for _ in $(seq 1 "$TRIES"); do
  if "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
    sleep 2
    exit 0
  fi
  sleep "$SLEEP"
done
exit 1
