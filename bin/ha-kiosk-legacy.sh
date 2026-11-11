#!/bin/bash
# Mode d’origine : Firefox kiosk-profile, plein écran, authSig jeton long (ha-api-token).
set -euo pipefail
LOCK=/tmp/ha-kiosk-legacy.lock
exec 8>"$LOCK"
flock -n 8 || exit 0

. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

export DISPLAY="${DISPLAY:-:0}"
export GNOME_KEYRING_CONTROL=
export SECRET_SERVICE_DISABLE=1
export MOZ_DISABLE_RDD_SANDBOX=1

# Wayfire = session Wayland ; Firefox en XWayland casse scroll/zoom tactile.
KIOSK_FIREFOX_WAYLAND="${KIOSK_FIREFOX_WAYLAND:-1}"
if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ]; then
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
  export GDK_BACKEND=wayland
  unset MOZ_DISABLE_WAYLAND
  export MOZ_ENABLE_WAYLAND=1
else
  unset WAYLAND_DISPLAY
  export MOZ_DISABLE_WAYLAND=1
  export MOZ_USE_XINPUT2=1
fi

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}"
SECOND_URL="${KIOSK_SECOND_URL:-}"

URL="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
  python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>/dev/null)" || URL="${HA_BASE}${PATH_VIEW}"

PROFILE="${HOME}/.mozilla/kiosk-profile"
mkdir -p "$PROFILE"
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json "$PROFILE"/recovery.json 2>/dev/null || true
rm -rf "$PROFILE"/sessionstore-backups 2>/dev/null || true
mkdir -p "$PROFILE"/sessionstore-backups

focus_ha_tab() {
  sleep 1
  if command -v wtype >/dev/null 2>&1; then
    wtype -M ctrl -k 1 2>/dev/null || true
  elif command -v xdotool >/dev/null 2>&1; then
    xdotool key --clearmodifiers ctrl+1 2>/dev/null || true
  fi
}

open_second_tab_background() {
  local url="$1"
  [ -z "$url" ] && return 0
  /usr/bin/firefox-esr --no-remote --profile "$PROFILE" -remote "openURL(${url},new-background-tab)" 2>/dev/null \
    || /usr/bin/firefox-esr --no-remote --profile "$PROFILE" -new-tab "$url" 2>/dev/null \
    || true
  focus_ha_tab
}
W=1920
H=1080
if [ "$KIOSK_FIREFOX_WAYLAND" != "1" ] && command -v xrandr >/dev/null 2>&1; then
  cur=$(xrandr 2>/dev/null | awk '/ connected /{f=1} f&&/\*/{print $1; exit}')
  if [ -n "$cur" ]; then
    W=${cur%x*}
    H=${cur#*x}
  fi
fi
"${HOME}/bin/kiosk-firefox-userjs.sh" "$PROFILE"

pkill -9 -f firefox-esr 2>/dev/null || true
sleep 2
pkill -f firefox-geometry-guard 2>/dev/null || true
pkill -x onboard 2>/dev/null || true

LOG="${HOME}/kiosk.log"
echo "=== ha-kiosk-legacy $(date) wayland=$KIOSK_FIREFOX_WAYLAND === URL=$URL" >>"$LOG"

FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized)
"${FF_CMD[@]}" "$URL" &

sleep 12
pgrep -f hide-desktop-loop >/dev/null || "${HOME}/bin/hide-desktop-loop.sh" &

if [ -n "$SECOND_URL" ]; then
  open_second_tab_background "$SECOND_URL"
  echo "2e onglet (arrière-plan): $SECOND_URL" >>"$LOG"
  focus_ha_tab
fi

if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ]; then
  pgrep -af "firefox-esr.*8123" | head -1 >>"$LOG"
  exit 0
fi

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
  focus_ha_tab
fi

pgrep -af "firefox-esr.*8123" | head -1 >>"$LOG"
exit 0
