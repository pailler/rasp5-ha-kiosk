#!/bin/bash
# Plein écran une seule fois (pas de boucle wtype / -remote).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

MODE="${KIOSK_FULLSCREEN:-fullscreen}"
[ "$MODE" = "kiosk" ] && exit 0
LOG="${HOME}/kiosk.log"

LOCK=/tmp/kiosk-apply-fullscreen.lock
exec 5>"$LOCK"
flock -n 5 || exit 0

"${HOME}/bin/kiosk-wayfire-window-rules.sh" 2>/dev/null || true

(
  sleep 12
  pgrep -x firefox-esr >/dev/null || exit 0
  if pgrep -af 'firefox-esr.*--kiosk' >/dev/null 2>&1; then
    echo "plein écran (--kiosk) déjà actif $(date)" >>"$LOG"
    exit 0
  fi
  "${HOME}/bin/kiosk-focus-firefox-window.sh" 2>/dev/null || true
  if [ "$MODE" = "f11" ] && command -v wtype >/dev/null 2>&1; then
    wtype -k F11 2>/dev/null || true
    echo "plein écran F11 (wtype) $(date)" >>"$LOG"
  elif command -v wtype >/dev/null 2>&1; then
    wtype -M super -k Up 2>/dev/null || wtype -M logo -k Up 2>/dev/null || true
    echo "plein écran maximize (wtype) $(date)" >>"$LOG"
  fi
  "${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
) &
