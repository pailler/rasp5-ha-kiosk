#!/bin/bash
# Relance Firefox seulement s’il est absent (jamais de -remote ici : channel error).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/kiosk.log"

exec 7>/tmp/kiosk-recover-display.lock
flock -n 7 || exit 0

recover_log() { echo "recover: $* $(date)" >>"$LOG"; }

if pgrep -f "start-kiosk-boot\\.sh" >/dev/null 2>&1 || pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1; then
  recover_log "boot en cours — skip"
  exit 0
fi

if "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
  recover_log "Firefox OK — pas de -remote"
  exit 0
fi

uptime_s=$(awk '{print int($1)}' /proc/uptime)
STAMP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kiosk-boot-once"
if [ "$uptime_s" -lt 900 ] || [ ! -f "$STAMP" ]; then
  recover_log "Firefox absent, boot pas fini — attente"
  exit 0
fi

recover_log "Firefox absent → relance unique"
rm -f /tmp/ha-kiosk-legacy.lock
exec 8>/tmp/kiosk-launch.lock
flock -n 8 || { recover_log "kiosk-launch déjà en cours"; exit 0; }
"${HOME}/bin/ha-kiosk-legacy.sh" >>"$LOG" 2>&1
