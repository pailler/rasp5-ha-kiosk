#!/bin/bash
# Recharge Lovelace si l’UI reste blanche (cartes custom lentes).
. "$(dirname "$0")/kiosk-session-env.sh"
STAMP=/tmp/kiosk-lovelace-nudge.count
count=$(cat "$STAMP" 2>/dev/null || echo 0)
[ "$count" -ge 8 ] && exit 0

pgrep -f "firefox-esr.*8123" >/dev/null || exit 0
WID=$(xdotool search --class firefox 2>/dev/null | while read -r wid; do
  name=$(xdotool getwindowname "$wid" 2>/dev/null)
  echo "$name" | grep -qiE 'home assistant|ecranmural|météo|meteo' && echo "$wid" && break
done | head -1)
[ -z "$WID" ] && exit 0

export DISPLAY="${DISPLAY:-:0}"
xdotool windowactivate --sync "$WID" 2>/dev/null
case "$count" in
  0|1|2) xdotool key --window "$WID" F5 ;;
  3|4) xdotool key --window "$WID" ctrl+shift+r ;;
  *) xdotool key --window "$WID" F5 ;;
esac
echo $((count + 1)) >"$STAMP"
