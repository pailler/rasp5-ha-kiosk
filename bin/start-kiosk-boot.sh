#!/bin/bash
# Un seul lancement Firefox kiosque par session (pas de boucle / pas de 2ᵉ ha-kiosk).
set -euo pipefail
LOCK=/tmp/start-kiosk-boot.lock
exec 9>"$LOCK"
flock -n 9 || exit 0

LOG="${HOME}/kiosk.log"
exec >>"$LOG" 2>&1
echo "=== start-kiosk-boot $(date) ==="

. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

STAMP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kiosk-boot-once"
if [ -f "$STAMP" ]; then
  echo "kiosque déjà initialisé cette session"
  exit 0
fi

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

for _ in $(seq 1 90); do
  if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -S /tmp/.X11-unix/X0 ] 2>/dev/null; then
    break
  fi
  sleep 1
done
export DISPLAY="${DISPLAY:-:0}"

if "${HOME}/bin/kiosk-browser-active.sh"; then
  echo "Firefox déjà actif"
  touch "$STAMP"
  exit 0
fi

if pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1; then
  echo "ha-kiosk-legacy déjà en cours — attente"
  for _ in $(seq 1 90); do
    if "${HOME}/bin/kiosk-browser-active.sh"; then
      touch "$STAMP"
      exit 0
    fi
    sleep 2
  done
fi

for _ in $(seq 1 45); do
  code="$(curl -o /dev/null -sS --max-time 4 -w "%{http_code}" "${HA_BASE}/" 2>/dev/null)" || code=0
  case "$code" in
    200|301|302|401|404) echo "HA joignable ($code)"; break ;;
  esac
  sleep 2
done

pkill -x onboard 2>/dev/null || true

if [ "${KIOSK_LEGACY:-0}" = "1" ]; then
  if ! pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1; then
    nohup "${HOME}/bin/ha-kiosk-legacy.sh" </dev/null >>"$LOG" 2>&1 &
  fi
else
  nohup "${HOME}/bin/ha-meteo-kiosk.sh" </dev/null >>"$LOG" 2>&1 &
fi

for _ in $(seq 1 60); do
  if "${HOME}/bin/kiosk-browser-active.sh"; then
    echo "kiosque OK"
    touch "$STAMP"
    "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
    exit 0
  fi
  sleep 2
done

echo "échec final kiosque (un seul lancement)"
exit 1
