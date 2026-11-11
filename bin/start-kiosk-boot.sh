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

if pgrep -f "chromium.*8123" >/dev/null 2>&1 || pgrep -f "firefox-esr.*8123" >/dev/null 2>&1; then
  echo "navigateur kiosque déjà actif"
  exit 0
fi

for _ in $(seq 1 90); do
  if curl -fsS --max-time 3 "${HA_BASE}/api/" >/dev/null 2>&1; then
  break
  fi
  sleep 2
done

"${HOME}/bin/ha-meteo-kiosk.sh" || true
sleep 5
pgrep -af "chromium.*8123|firefox-esr.*8123" | head -3 || echo "échec lancement kiosque"
