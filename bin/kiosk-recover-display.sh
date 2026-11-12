#!/bin/bash
# Écran noir ou fenêtres multiples : taille, focus, pas de tempête de lancements.
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

uptime_s=$(awk '{print int($1)}' /proc/uptime)
if [ "$uptime_s" -lt 900 ]; then
  recover_log "grace boot ${uptime_s}s — pas de relance"
fi

if pgrep -f "start-kiosk-boot\\.sh" >/dev/null 2>&1 || pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1; then
  recover_log "boot en cours — skip"
  exit 0
fi

mapfile -t _ff < <(pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null || true)
n=${#_ff[@]}

if [ "$n" -gt 1 ]; then
  recover_log "${n} Firefox — élagage"
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" || true
  sleep 1
  n=1
fi

if [ "$n" -ge 1 ]; then
  recover_log "1 Firefox → focus HA"
  "${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
  exit 0
fi

STAMP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kiosk-boot-once"
if [ "$uptime_s" -lt 900 ] || [ ! -f "$STAMP" ]; then
  recover_log "Firefox absent mais boot pas stabilisé — pas de relance"
  exit 0
fi

recover_log "Firefox absent (post-boot) → relance unique"
rm -f /tmp/ha-kiosk-legacy.lock
exec 8>/tmp/kiosk-launch.lock
flock -n 8 || { recover_log "kiosk-launch déjà en cours"; exit 0; }
"${HOME}/bin/ha-kiosk-legacy.sh" >>"$LOG" 2>&1
