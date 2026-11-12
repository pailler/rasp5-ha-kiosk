#!/bin/bash
# Attend Firefox ESR + instance -remote prête (évite une 2e fenêtre au -remote).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
PROFILE="${HOME}/.mozilla/kiosk-profile"
TRIES="${1:-40}"
SLEEP="${2:-2}"

for _ in $(seq 1 "$TRIES"); do
  pgrep -x firefox-esr >/dev/null 2>&1 || { sleep "$SLEEP"; continue; }
  out="$(timeout 4 /usr/bin/firefox-esr --profile "$PROFILE" -remote 'ping()' 2>&1)" || out=""
  if [ -n "$out" ] && ! echo "$out" | grep -qiE 'failed|not running|cannot'; then
    exit 0
  fi
  sleep "$SLEEP"
done
exit 1
