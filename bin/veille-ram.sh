#!/bin/bash
LOG="${HOME}/veille.log"
{
  echo "=== veille-ram $(date) ==="
  systemctl --user stop firefox-geometry-guard.service 2>/dev/null || true
  pkill -9 -f firefox-esr 2>/dev/null || true
  sleep 1
  vcgencmd display_power 0 2>/dev/null || true
  export DISPLAY="${DISPLAY:-:0}"
  xset dpms force off 2>/dev/null || true
  echo "Firefox arrêté, écran coupé si possible"
} >>"$LOG" 2>&1
touch "${HOME}/.kiosk-veille-active"
