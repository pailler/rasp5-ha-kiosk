#!/bin/bash
# Attend Firefox kiosque. Si KIOSK_NO_REMOTE=1 : pas de ping -remote (crash Pi 5).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
TRIES="${1:-40}"
SLEEP="${2:-2}"

if [ "${KIOSK_NO_REMOTE:-1}" = "1" ]; then
  exec "${HOME}/bin/kiosk-wait-firefox-process.sh" "$TRIES" "$SLEEP"
fi

PROFILE="${HOME}/.mozilla/kiosk-profile"
for _ in $(seq 1 "$TRIES"); do
  pgrep -x firefox-esr >/dev/null 2>&1 || { sleep "$SLEEP"; continue; }
  out="$(timeout 4 /usr/bin/firefox-esr --profile "$PROFILE" -remote 'ping()' 2>&1)" || out=""
  if [ -n "$out" ] && ! echo "$out" | grep -qiE 'failed|not running|cannot'; then
    exit 0
  fi
  sleep "$SLEEP"
done
exit 1
