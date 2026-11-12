#!/bin/bash
# Charge une URL : relance Firefox kiosque (fiable sur Pi 5, pas de xdotool/-remote).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
url="${1:-}"
[ -n "$url" ] || exit 1

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

KIOSK_NAV_MODE="${KIOSK_NAV_MODE:-relaunch}"
if [ "$KIOSK_NAV_MODE" = "soft" ]; then
  if [ "${KIOSK_FIREFOX_WAYLAND:-0}" != "1" ]; then
    "${HOME}/bin/kiosk-xdotool-goto-url.sh" "$url" 2>/dev/null && exit 0
  elif command -v wtype >/dev/null 2>&1; then
    "${HOME}/bin/kiosk-wtype-goto-url.sh" "$url" 2>/dev/null && exit 0
  fi
fi

PROFILE="${HOME}/.mozilla/kiosk-profile"
echo "goto-url: relance Firefox → ${url%%\?*}… $(date)" >>"$LOG"
pkill -9 -f 'firefox-esr.*kiosk-profile' 2>/dev/null || pkill -x firefox-esr 2>/dev/null || true
sleep 1
rm -f /tmp/kiosk-firefox-launch.lock /tmp/ha-kiosk-legacy.lock
nohup /usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized "$url" \
  </dev/null >>"$LOG" 2>&1 &
disown 2>/dev/null || true

for _ in $(seq 1 25); do
  if pgrep -x firefox-esr >/dev/null; then
    echo "goto-url: Firefox actif $(date)" >>"$LOG"
    exit 0
  fi
  sleep 1
done
echo "goto-url: timeout démarrage Firefox $(date)" >>"$LOG"
exit 1
