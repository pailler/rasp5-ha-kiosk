#!/bin/bash
# Mode d’origine : Firefox kiosk-profile, plein écran F11, authSig jeton long (ha-api-token).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

export DISPLAY="${DISPLAY:-:0}"
unset WAYLAND_DISPLAY
export MOZ_DISABLE_WAYLAND=1
export MOZ_DISABLE_RDD_SANDBOX=1
export MOZ_USE_XINPUT2=1
export GNOME_KEYRING_CONTROL=
export SECRET_SERVICE_DISABLE=1

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}"
SECOND_URL="${KIOSK_SECOND_URL:-}"

URL="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
  python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>/dev/null)" || URL="${HA_BASE}${PATH_VIEW}"

PROFILE="${HOME}/.mozilla/kiosk-profile"
mkdir -p "$PROFILE"
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json 2>/dev/null || true
W=1920
H=1080
if command -v xrandr >/dev/null 2>&1; then
  cur=$(xrandr 2>/dev/null | awk '/ connected /{f=1} f&&/\*/{print $1; exit}')
  if [ -n "$cur" ]; then
    W=${cur%x*}
    H=${cur#*x}
  fi
fi
"${HOME}/bin/kiosk-firefox-userjs.sh" "$PROFILE"

pkill -9 -f firefox-esr 2>/dev/null || true
sleep 2
pkill -x onboard 2>/dev/null || true

LOG="${HOME}/kiosk.log"
echo "=== ha-kiosk-legacy $(date) === URL=$URL" >>"$LOG"
/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized "$URL" &

sleep 10
pgrep -f hide-desktop-loop >/dev/null || "${HOME}/bin/hide-desktop-loop.sh" &
pgrep -f firefox-geometry-guard >/dev/null || "${HOME}/bin/firefox-geometry-guard.sh" &

find_ha_window() {
  local wid name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    echo "$name" | grep -qiE 'home assistant|ecranmural|météo|meteo|mozilla firefox' && echo "$wid" && return 0
  done
  return 1
}

WID=""
for _ in $(seq 1 25); do
  WID=$(find_ha_window || true)
  [ -n "$WID" ] && break
  sleep 2
done
[ -z "$WID" ] && exit 1

FULLSCREEN_MODE="${KIOSK_FULLSCREEN:-maximize}"

for _ in 1 2 3 4 5; do
  xdotool windowmove --sync "$WID" 0 0 2>/dev/null || true
  xdotool windowsize --sync "$WID" "$W" "$H" 2>/dev/null || true
  if [ "$FULLSCREEN_MODE" = "f11" ]; then
    xdotool key --window "$WID" F11 2>/dev/null || true
  fi
  sleep 2
  eval "$(xdotool getwindowgeometry --shell "$WID" 2>/dev/null)"
  [ "${WIDTH:-0}" -ge "$((W - 20))" ] && [ "${HEIGHT:-0}" -ge "$((H - 20))" ] && break
done
xdotool windowactivate --sync "$WID" 2>/dev/null || true

if [ -n "$SECOND_URL" ]; then
  xdotool windowactivate --sync "$WID" 2>/dev/null || true
  xdotool key --window "$WID" ctrl+t 2>/dev/null || true
  sleep 2
  xdotool type --delay 35 --window "$WID" -- "$SECOND_URL" 2>/dev/null || true
  xdotool key --window "$WID" Return 2>/dev/null || true
  sleep 3
  xdotool key --window "$WID" ctrl+1 2>/dev/null || true
  echo "2e onglet: $SECOND_URL" >>"$LOG"
fi

pgrep -af "firefox-esr.*8123" | head -1 >>"$LOG"
exit 0
