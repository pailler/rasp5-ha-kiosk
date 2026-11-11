#!/bin/bash
# shellcheck source=kiosk-session-env.sh
. "$(dirname "$0")/kiosk-session-env.sh"
export DISPLAY="${DISPLAY:-:0}"
URL="http://192.168.1.51:8123/lovelace/ecranmural"
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
  local best="" best_area=0 wid name w h area
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
    w=${WIDTH:-0}; h=${HEIGHT:-0}
    area=$((w * h))
    echo "$name" | grep -qiE 'home assistant|météo|meteo|mozilla firefox' || continue
    [ "$w" -lt 400 ] && continue
    if [ "$area" -gt "$best_area" ]; then best_area=$area; best=$wid; fi
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

if pgrep -x firefox-esr >/dev/null && pgrep -af "firefox-esr.*lovelace/ecranmural" >/dev/null 2>&1; then
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

python3 "${HOME}/bin/ha-kiosk-inject-ha-auth.py" || true

PROFILE="${HOME}/.mozilla/ha-kiosk-profile"
mkdir -p "$PROFILE"
cat >"$PROFILE/user.js" <<'USERJS'
user_pref("dom.ipc.processCount", 2);
user_pref("dom.ipc.processCount.web", 2);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.sessionstore.restore_on_demand", true);
user_pref("browser.sessionstore.max_tabs_undo", 0);
USERJS

firefox-esr -profile "$PROFILE" -no-remote -kiosk "$URL" &
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  WID=$(find_main_window)
  [ -n "$WID" ] && resize_main_window "$WID"
  eval "$(xdotool getwindowgeometry --shell "$WID" 2>/dev/null)"
  [ "${WIDTH:-0}" -eq "$W" ] && [ "${HEIGHT:-0}" -eq "$H" ] && exit 0
  sleep 1
done
if pgrep -x firefox-esr >/dev/null; then
  WID=$(find_main_window)
  [ -n "$WID" ] && resize_main_window "$WID"
  exit 0
fi
exit 1
