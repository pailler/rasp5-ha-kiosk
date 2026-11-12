#!/bin/bash
# Écran noir : Firefox absent ou onglet 1 / fenêtre pas visibles.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

exec 7>/tmp/kiosk-recover-display.lock
flock -n 7 || exit 0

recover_log() { echo "recover: $* $(date)" >>"$LOG"; }

if pgrep -x firefox-esr >/dev/null 2>&1; then
  recover_log "Firefox actif → focus onglet HA + plein écran"
  "${HOME}/bin/kiosk-wait-firefox-remote.sh" 15 2 2>/dev/null || true
  "${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
  sleep 0.5
  "${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
  exit 0
fi

if pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1; then
  recover_log "ha-kiosk-legacy en cours — attente"
  exit 0
fi

if pgrep -f "start-kiosk-boot\\.sh" >/dev/null 2>&1; then
  recover_log "boot kiosque en cours — skip"
  exit 0
fi

recover_log "Firefox absent — relance kiosque"
rm -f /tmp/ha-kiosk-legacy.lock
"${HOME}/bin/kiosk-launch.sh" >>"$LOG" 2>&1
