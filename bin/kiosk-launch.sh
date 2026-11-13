#!/bin/bash
# Point d'entrée unique : legacy ou mode moderne.
set -euo pipefail
LOCK=/tmp/kiosk-launch.lock
exec 9>"$LOCK"
flock -n 9 || exit 0

. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

if "${HOME}/bin/kiosk-ha-browser-active.sh" 2>/dev/null; then
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" 2>/dev/null || true
  exit 0
fi

if [ "${KIOSK_HA_USE_CHROMIUM:-0}" = "1" ]; then
  PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}"
  if "${HOME}/bin/kiosk-return-ha.sh" "$PATH_VIEW"; then
    exit 0
  fi
  exit 1
fi

if [ "${KIOSK_LEGACY:-0}" = "1" ]; then
  exec "${HOME}/bin/ha-kiosk-legacy.sh"
fi
exec "${HOME}/bin/ha-meteo-kiosk.sh"
