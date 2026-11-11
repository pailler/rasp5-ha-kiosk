#!/bin/bash
exec 9>/tmp/firefox-geometry-guard.lock
flock -n 9 || exit 0
export DISPLAY="${DISPLAY:-:0}"
TARGET_W=1920
TARGET_H=1080

if command -v xrandr >/dev/null 2>&1; then
  cur=$(xrandr 2>/dev/null | awk '/ connected /{f=1} f&&/\*/{print $1; exit}')
  if [ -n "$cur" ]; then
    TARGET_W=${cur%x*}
    TARGET_H=${cur#*x}
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

while true; do
  if ! pgrep -x firefox-esr >/dev/null; then
    sleep 5
    continue
  fi
  WID=$(find_main_window)
  if [ -n "$WID" ]; then
    eval "$(xdotool getwindowgeometry --shell "$WID" 2>/dev/null)"
    dw=$((TARGET_W - WIDTH))
    dh=$((TARGET_H - HEIGHT))
    [ "$dw" -lt 0 ] && dw=$((-dw))
    [ "$dh" -lt 0 ] && dh=$((-dh))
    if [ "$dw" -gt 40 ] || [ "$dh" -gt 40 ] || [ "${X:-1}" -ne 0 ] || [ "${Y:-1}" -ne 0 ]; then
      xdotool windowmove --sync "$WID" 0 0 2>/dev/null
      xdotool windowsize --sync "$WID" "$TARGET_W" "$TARGET_H" 2>/dev/null
    fi
  fi
  sleep 15
done
