#!/bin/bash
# Kiosque HA réellement utilisable (processus + renderer + HA joignable).
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

export DISPLAY="${DISPLAY:-:0}"
"${HOME}/bin/kiosk-ha-browser-active.sh" 2>/dev/null || exit 1

if [ "${KIOSK_HA_USE_CHROMIUM:-0}" = "1" ]; then
  pgrep -f "chromium.*type=renderer" >/dev/null 2>&1 || exit 1
fi

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
curl -fsS -m 6 -o /dev/null "${HA_BASE}/" 2>/dev/null || exit 1
exit 0