#!/bin/bash
LOG="${HOME}/veille.log"
# shellcheck source=kiosk-session-env.sh
. "${HOME}/bin/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

{
  echo "=== reveil-kiosk $(date) ==="
  export DISPLAY="${DISPLAY:-:0}"
  xset -q >/dev/null 2>&1 || echo "avertissement: X11 unreachable (DISPLAY=$DISPLAY)"
  xset dpms force on 2>/dev/null || true
  xset s reset 2>/dev/null || true
  vcgencmd display_power 1 2>/dev/null || true

  systemctl --user start hide-desktop.service firefox-geometry-guard.service 2>/dev/null || true

  ok=0
  if "${HOME}/bin/kiosk-launch.sh"; then
    ok=1
  elif "${HOME}/bin/kiosk-ha-browser-active.sh"; then
    ok=1
  fi
  if [ "$ok" -eq 1 ]; then
    rm -f "${HOME}/.kiosk-veille-active"
    xsetroot -solid black 2>/dev/null || true
    echo "réveil OK kiosque lancé (chromium=${KIOSK_HA_USE_CHROMIUM:-0})"
  else
    echo "ÉCHEC kiosk-launch → on garde le flag veille"
    touch "${HOME}/.kiosk-veille-active"
    exit 1
  fi
} >>"$LOG" 2>&1
