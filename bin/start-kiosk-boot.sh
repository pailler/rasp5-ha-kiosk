#!/bin/bash
# Attente réseau + HA puis lance ha-meteo-kiosk (Chromium / Firefox + auth).
set -euo pipefail
LOCK=/tmp/start-kiosk-boot.lock
exec 9>"$LOCK"
flock -n 9 || exit 0

LOG="${HOME}/kiosk.log"
exec >>"$LOG" 2>&1
echo "=== start-kiosk-boot $(date) ==="

. "$(dirname "$0")/kiosk-session-env.sh"

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

for _ in $(seq 1 120); do
  [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY:-wayland-1}" ] \
    && [ -S /tmp/.X11-unix/X0 ] && break
  sleep 1
done
export DISPLAY="${DISPLAY:-:0}"

if pgrep -f "chromium.*8123" >/dev/null 2>&1 \
  || pgrep -f "firefox-esr.*8123" >/dev/null 2>&1; then
  echo "navigateur kiosque déjà actif"
  exit 0
fi

ha_reachable() {
  local code
  code="$(curl -o /dev/null -sS --max-time 4 -w "%{http_code}" "${HA_BASE}/" 2>/dev/null)" || return 1
  case "$code" in
    200|301|302|401|404) return 0 ;;
    *) return 1 ;;
  esac
}

for _ in $(seq 1 60); do
  if ha_reachable; then
    echo "HA joignable (http ${code:-?})"
    break
  fi
  sleep 2
done

"${HOME}/bin/ha-meteo-kiosk.sh" || true
sleep 5
pgrep -af "chromium.*8123|firefox-esr.*8123" | head -3 || echo "échec lancement kiosque"
