#!/bin/bash
# shellcheck source=kiosk-session-env.sh
. "$(dirname "$0")/kiosk-session-env.sh"
CONF_FILE="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF_FILE" ] && . "$CONF_FILE"
export DISPLAY="${DISPLAY:-:0}"
KIOSK_LOVELACE_PATH="${KIOSK_LOVELACE_PATH:-/pi-kiosk-dash/test}"
KIOSK_BROWSER="${KIOSK_BROWSER:-firefox-esr}"
HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
USE_OAUTH=0
[ -r "${HOME}/.config/ha-kiosk-login" ] && USE_OAUTH=1

if [ "$USE_OAUTH" -eq 1 ]; then
  python3 "${HOME}/bin/ha-kiosk-oauth-login.py" 2>/dev/null || USE_OAUTH=0
fi

"${HOME}/bin/kiosk-virtual-keyboard.sh" 2>/dev/null || true

if [ -n "${KIOSK_URL:-}" ]; then
  URL="$KIOSK_URL"
elif [ "$USE_OAUTH" -eq 1 ]; then
  URL="${HA_BASE}${KIOSK_LOVELACE_PATH}"
else
  KIOSK_URL="$(HA_URL="$HA_BASE" KIOSK_PATH="$KIOSK_LOVELACE_PATH" python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>/dev/null)" || true
  URL="${KIOSK_URL:-${HA_BASE}${KIOSK_LOVELACE_PATH}}"
fi
export KIOSK_PATH="$KIOSK_LOVELACE_PATH"
W=1920
H=1080

pkill -f "pcmanfm --desktop" 2>/dev/null || true
pkill -x lxpanel 2>/dev/null || true
xsetroot -solid black 2>/dev/null || true
pgrep -f hide-desktop-loop >/dev/null || "${HOME}/bin/hide-desktop-loop.sh" &
pgrep -f firefox-geometry-guard >/dev/null || "${HOME}/bin/firefox-geometry-guard.sh" &

if command -v xrandr >/dev/null 2>&1; then
  cur=$(xrandr 2>/dev/null | awk '/ connected /{f=1} f&&/\*/{print $1; exit}')
  if [ -n "$cur" ]; then
    W=${cur%x*}
    H=${cur#*x}
  fi
fi

find_main_window() {
  local best="" best_area=0 wid name w h area win_class
  for win_class in firefox Chromium chromium; do
  for wid in $(xdotool search --class "$win_class" 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
    w=${WIDTH:-0}; h=${HEIGHT:-0}
    area=$((w * h))
    echo "$name" | grep -qiE 'home assistant|météo|meteo|mozilla firefox' || continue
    [ "$w" -lt 400 ] && continue
    if [ "$area" -gt "$best_area" ]; then best_area=$area; best=$wid; fi
  done
  done
  echo "$best"
}

resize_main_window() {
  local wid="$1"
  [ -z "$wid" ] && return 1
  xdotool windowactivate --sync "$wid" 2>/dev/null
  xdotool windowmove --sync "$wid" 0 0 2>/dev/null
  xdotool windowsize --sync "$wid" "$W" "$H" 2>/dev/null
}

if pgrep -x firefox-esr >/dev/null && pgrep -af "firefox-esr.*8123" >/dev/null 2>&1; then
  WID=$(find_main_window)
  if [ -n "$WID" ]; then
    resize_main_window "$WID"
    exit 0
  fi
fi
if pgrep -f "chromium.*8123" >/dev/null 2>&1; then
  WID=$(find_main_window)
  if [ -n "$WID" ]; then
    resize_main_window "$WID"
    exit 0
  fi
fi

if pgrep -x firefox-esr >/dev/null; then
  pkill -x firefox-esr || true
  sleep 2
fi
pkill -f "/usr/lib/chromium/chromium" 2>/dev/null || pkill -x chromium 2>/dev/null || true
sleep 1

if [ "$USE_OAUTH" -eq 1 ] || [[ "$URL" != *authSig=* ]]; then
  python3 "${HOME}/bin/ha-kiosk-inject-ha-auth.py" || true
  if [ "$KIOSK_BROWSER" = "chromium" ]; then
    python3 "${HOME}/bin/ha-kiosk-inject-chromium-auth.py" 2>/dev/null || true
    python3 "${HOME}/bin/ha-kiosk-chromium-extension.py" 2>/dev/null || true
  fi
fi

PROFILE="${HOME}/.mozilla/ha-kiosk-profile"
mkdir -p "$PROFILE"
cat >"$PROFILE/user.js" <<'USERJS'
user_pref("dom.ipc.processCount", 4);
user_pref("dom.ipc.processCount.web", 4);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.sessionstore.restore_on_demand", true);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("layers.acceleration.force-disabled", true);
user_pref("gfx.webrender.all", false);
user_pref("dom.max_hardware_canvas_dimension", 4096);
USERJS

if [ "$KIOSK_BROWSER" = "chromium" ] && command -v chromium >/dev/null 2>&1; then
  CHR_PROFILE="${HOME}/.config/chromium-kiosk"
  CHR_EXT="${HOME}/.config/ha-kiosk-chromium-ext"
  mkdir -p "$CHR_PROFILE"
  CHROME_EXTRA=()
  if [ -d "$CHR_EXT" ] && [ -f "$CHR_EXT/manifest.json" ]; then
    CHROME_EXTRA+=(--disable-extensions-except="$CHR_EXT" --load-extension="$CHR_EXT")
  fi
  chromium --user-data-dir="$CHR_PROFILE" \
    --kiosk --noerrdialogs --disable-infobars --no-first-run \
    --disable-session-crashed-bubble --password-store=basic \
    --disable-features=Translate,TranslateUI \
    --disable-gpu --disable-dev-shm-usage \
    "${CHROME_EXTRA[@]}" \
    "$URL" &
else
  firefox-esr -profile "$PROFILE" -no-remote -kiosk "$URL" &
fi

# Lovelace lourd (masonry) : rechargement différé si l’UI reste blanche
(
  sleep 30
  WID=$(find_main_window)
  [ -n "$WID" ] && xdotool key --window "$WID" F5 2>/dev/null
  sleep 25
  WID=$(find_main_window)
  [ -n "$WID" ] && xdotool key --window "$WID" F5 2>/dev/null
) &

for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  WID=$(find_main_window)
  [ -n "$WID" ] && resize_main_window "$WID"
  eval "$(xdotool getwindowgeometry --shell "$WID" 2>/dev/null)"
  [ "${WIDTH:-0}" -eq "$W" ] && [ "${HEIGHT:-0}" -eq "$H" ] && exit 0
  sleep 1
done
if pgrep -x firefox-esr >/dev/null || pgrep -f "chromium.*8123" >/dev/null; then
  WID=$(find_main_window)
  [ -n "$WID" ] && resize_main_window "$WID"
  exit 0
fi
exit 1
