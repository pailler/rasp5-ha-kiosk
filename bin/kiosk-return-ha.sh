#!/bin/bash
# Retour mur → Chromium HA (fiable) ou Firefox legacy (KIOSK_HA_USE_CHROMIUM=0).
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
sleep 0.5
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true

url=""
for try in 1 2 3 4 5; do
  url="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
    python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || url=""
  [[ "$url" == *authSig=* ]] && break
  sleep 2
done
[ -z "$url" ] && url="${HA_BASE}${PATH_VIEW}"
printf '%s\n' "$url" >"${HOME}/.cache/kiosk-last-ha-url"

echo "return-ha: $PATH_VIEW $(date)" >>"$LOG"

if [ "${KIOSK_HA_USE_CHROMIUM:-1}" = "1" ]; then
  if "${HOME}/bin/kiosk-ha-chromium.sh" "$url"; then
    echo "return-ha: ha-chromium OK $(date)" >>"$LOG"
    exit 0
  fi
  echo "return-ha: ha-chromium échec, repli Firefox $(date)" >>"$LOG"
fi

export KIOSK_LOVELACE_PATH="$PATH_VIEW"
export KIOSK_FORCE_RELAUNCH=1
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
"${HOME}/bin/ha-kiosk-legacy.sh" || true
"${HOME}/bin/kiosk-lovelace-nudge.sh" 2>/dev/null || true
echo "return-ha: legacy done $(date)" >>"$LOG"
