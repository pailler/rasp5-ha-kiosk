#!/bin/bash
# Lance Firefox kiosque une seule fois (flock).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/kiosk.log"

LOCK=/tmp/kiosk-firefox-launch.lock
exec 6>"$LOCK"
if ! flock -n 6; then
  echo "firefox-launch-once: verrou actif — autre lancement $(date)" >>"$LOG"
  exit 0
fi

if "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" || true
  "${HOME}/bin/kiosk-ensure-ha-url.sh" 2>/dev/null || true
  exit 0
fi

echo "firefox-launch-once: $* $(date)" >>"$LOG"
nohup /usr/bin/firefox-esr "$@" </dev/null >>"$LOG" 2>&1 &
disown -a 2>/dev/null || true
