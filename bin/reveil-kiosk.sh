#!/bin/bash
LOG="${HOME}/veille.log"
# shellcheck source=kiosk-session-env.sh
. "${HOME}/bin/kiosk-session-env.sh"

{
  echo "=== reveil-kiosk $(date) ==="
  export DISPLAY="${DISPLAY:-:0}"
  xset -q >/dev/null 2>&1 || echo "avertissement: X11 unreachable (DISPLAY=$DISPLAY)"
  xset dpms force on 2>/dev/null || true
  xset s reset 2>/dev/null || true
  vcgencmd display_power 1 2>/dev/null || true

  systemctl --user start hide-desktop.service firefox-geometry-guard.service 2>/dev/null || true

  if "${HOME}/bin/kiosk-launch.sh"; then
    rm -f "${HOME}/.kiosk-veille-active"
    echo "réveil OK firefox lancé"
  else
    echo "ÉCHEC ha-meteo-kiosk → on garde le flag veille"
    touch "${HOME}/.kiosk-veille-active"
    exit 1
  fi
} >>"$LOG" 2>&1
