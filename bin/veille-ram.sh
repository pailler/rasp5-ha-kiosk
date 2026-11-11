#!/bin/bash
LOG="${HOME}/veille.log"
# shellcheck source=kiosk-session-env.sh
. "${HOME}/bin/kiosk-session-env.sh"

{
  echo "=== veille-ram $(date) ==="
  systemctl --user stop firefox-geometry-guard.service 2>/dev/null || true
  pkill -9 -x firefox-esr 2>/dev/null || pkill -9 -f firefox-esr 2>/dev/null || true
  pkill -x chromium 2>/dev/null || pkill -f "chromium.*8123" 2>/dev/null || true
  sleep 1
  xset dpms force off 2>/dev/null || true
  vcgencmd display_power 0 2>/dev/null || true
  echo "Firefox arrêté, écran coupé si possible"
} >>"$LOG" 2>&1
touch "${HOME}/.kiosk-veille-active"
