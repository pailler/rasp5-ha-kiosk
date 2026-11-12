#!/bin/bash
# Retour mur → Firefox + Lovelace signé (après Chromium YouTube).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
PATH_VIEW="${1:-${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}}"
case "$PATH_VIEW" in
  /*) ;;
  *) PATH_VIEW="/${PATH_VIEW}" ;;
esac

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

pkill -x chromium 2>/dev/null || true
sleep 1
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true

url=""
for try in 1 2 3; do
  url="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
    python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || url=""
  [[ "$url" == *authSig=* ]] && break
  sleep 2
done
[ -z "$url" ] && url="${HA_BASE}${PATH_VIEW}"
printf '%s\n' "$url" >"${HOME}/.cache/kiosk-last-ha-url"

echo "return-ha: $PATH_VIEW $(date)" >>"$LOG"
KIOSK_YOUTUBE_USE_CHROMIUM=0 "${HOME}/bin/kiosk-firefox-goto-url.sh" "$url"
