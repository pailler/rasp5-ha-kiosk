#!/bin/bash
# Point d'entrée unique : legacy ou mode moderne.
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
if [ "${KIOSK_LEGACY:-0}" = "1" ]; then
  exec "${HOME}/bin/ha-kiosk-legacy.sh"
fi
exec "${HOME}/bin/ha-meteo-kiosk.sh"
