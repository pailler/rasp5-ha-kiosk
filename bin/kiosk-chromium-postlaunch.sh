#!/bin/bash
# Après relance Chromium HA : règles Wayfire + focus plein écran.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
[ "${KIOSK_HA_USE_CHROMIUM:-0}" = "1" ] || exit 0

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

"${HOME}/bin/kiosk-display-wake.sh" 2>/dev/null || true
"${HOME}/bin/kiosk-wayfire-window-rules.sh" 2>/dev/null || true

for _ in 1 2 3 4 5 6 8 10 12 15; do
  pgrep -f "chromium.*type=renderer" >/dev/null 2>&1 && break
  sleep 1
done

if command -v wtype >/dev/null 2>&1; then
  wtype -M super -k Up 2>/dev/null || wtype -M logo -k Up 2>/dev/null || true
  sleep 0.3
  wtype -k F11 2>/dev/null || true
fi