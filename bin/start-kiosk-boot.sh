#!/bin/bash
# Un seul lancement Firefox kiosque par session (pas de boucle / pas de 2ᵉ ha-kiosk).
set -euo pipefail
LOCK=/tmp/start-kiosk-boot.lock
exec 9>"$LOCK"
flock -n 9 || exit 0

LOG="${HOME}/kiosk.log"
if [ -f "$LOG" ] && grep -q $'\0' "$LOG" 2>/dev/null; then
  mv -f "$LOG" "${LOG}.bak.$(date +%s)" 2>/dev/null || true
fi
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
  "${HOME}/bin/kiosk-prune-extra-firefox.sh" 2>/dev/null || true
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

for _ in $(seq 1 90); do
  if ! "${HOME}/bin/kiosk-browser-active.sh"; then
    sleep 2
    continue
  fi
  if [ -x "${HOME}/bin/kiosk-wait-firefox-remote.sh" ]; then
    "${HOME}/bin/kiosk-wait-firefox-remote.sh" 15 2 >/dev/null || { sleep 2; continue; }
  fi
  sleep 5
  "${HOME}/bin/kiosk-browser-active.sh" || { sleep 2; continue; }
  if [ -x "${HOME}/bin/kiosk-prune-extra-firefox.sh" ]; then
    "${HOME}/bin/kiosk-prune-extra-firefox.sh" || true
    sleep 1
  fi
  n=$("${HOME}/bin/kiosk-list-main-firefox.sh" 2>/dev/null | wc -l)
  [ "$n" -ge 1 ] || { sleep 2; continue; }
  echo "kiosque OK (instances=${n})"
  touch "$STAMP"
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
  (
    sleep 120
    pgrep -x firefox-esr >/dev/null && "${HOME}/bin/kiosk-nudge-ha.sh" || "${HOME}/bin/kiosk-recover-display.sh"
  ) &
  exit 0
done

echo "échec final kiosque (un seul lancement)"
exit 1
