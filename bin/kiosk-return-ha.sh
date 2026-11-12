#!/bin/bash
# Retour mur → ha-kiosk-legacy (relance forcée après Chromium).
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

pkill -x chromium 2>/dev/null || true
sleep 1
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true

export KIOSK_LOVELACE_PATH="$PATH_VIEW"
export KIOSK_FORCE_RELAUNCH=1
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

echo "return-ha: legacy $PATH_VIEW $(date)" >>"$LOG"
"${HOME}/bin/ha-kiosk-legacy.sh" || true
sleep 3
"${HOME}/bin/kiosk-lovelace-nudge.sh" 2>/dev/null || true
echo "return-ha: done $(date)" >>"$LOG"
