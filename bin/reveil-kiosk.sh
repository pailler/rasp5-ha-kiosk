#!/bin/bash
LOG="${HOME}/veille.log"
{
  echo "=== reveil-kiosk $(date) ==="
  rm -f "${HOME}/.kiosk-veille-active"
  vcgencmd display_power 1 2>/dev/null || true
  export DISPLAY="${DISPLAY:-:0}"
  xset dpms force on 2>/dev/null || true
  systemctl --user start firefox-geometry-guard.service 2>/dev/null || true
  "${HOME}/bin/ha-meteo-kiosk.sh"
} >>"$LOG" 2>&1
