#!/bin/bash
# Barre d’adresse Firefox via XWayland (wtype ne marche pas sur X11).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
url="${1:-}"
[ -n "$url" ] || exit 1
command -v xdotool >/dev/null 2>&1 || exit 1
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

wid=""
for try in 1 2 3 4 5; do
  wid="$(xdotool search --class firefox 2>/dev/null | tail -1)"
  [ -n "$wid" ] && break
  sleep 0.4
done
[ -n "$wid" ] || exit 1

xdotool windowactivate --sync "$wid" 2>/dev/null || true
sleep 0.2
xdotool key --clearmodifiers --window "$wid" ctrl+l 2>/dev/null || xdotool key --window "$wid" F6 2>/dev/null || true
sleep 0.35
xdotool key --clearmodifiers --window "$wid" ctrl+a 2>/dev/null || true
sleep 0.05
xdotool type --clearmodifiers --delay 5 --window "$wid" -- "$url" 2>/dev/null || exit 1
sleep 0.05
xdotool key --clearmodifiers --window "$wid" Return 2>/dev/null || exit 1
exit 0
