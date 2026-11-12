#!/bin/bash
# YouTube mur : Chromium plein écran (Firefox iframe file:// = écran blanc sur Pi).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/kiosk.log"
src="${1:-}"
[ -n "$src" ] || exit 1

command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1 || exit 1

vid="$(VID_SOURCE="$src" python3 - <<'PY'
import os, re, urllib.parse
src = os.environ.get("VID_SOURCE", "")
vid = ""
if "youtu.be/" in src:
    vid = src.split("youtu.be/", 1)[1].split("?")[0].split("/")[0]
else:
    m = re.search(r"[?&]v=([^&]+)", src)
    if m:
        vid = m.group(1)
    m2 = re.search(r"/embed/([^?&/]+)", src)
    if not vid and m2:
        vid = m2.group(1)
if "mural-youtube-embed" in src and "v=" in src:
    q = src.split("?", 1)[1] if "?" in src else ""
    params = urllib.parse.parse_qs(q)
    vid = (params.get("v") or [""])[0]
print(vid.strip())
PY
)"
[ "${#vid}" -ge 6 ] || exit 1

mute=0
case "$src" in
  *mute=1*|*mute=true*) mute=1 ;;
esac

CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
mode="${KIOSK_YOUTUBE_MODE:-embed-page}"

if [[ "$src" == *"/youtube?"* ]] || [[ "$src" == *"/youtube?v="* ]]; then
  page="$src"
else
embed_qs="autoplay=1&playsinline=1&rel=0&modestbranding=1&fs=1"
[ "$mute" -eq 1 ] && embed_qs="${embed_qs}&mute=1"

if [ "$mode" = "ha-embed" ]; then
  HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
  HA_BASE="${HA_BASE%/}"
  page="${HA_BASE}/local/mural-youtube-embed.html?v=${vid}"
  [ "$mute" -eq 1 ] && page="${page}&mute=1"
elif [ "$mode" = "embed-page" ]; then
  port="${KIOSK_HTTP_PORT:-8765}"
  host="${KIOSK_YOUTUBE_ORIGIN_HOST:-127.0.0.1}"
  page="http://${host}:${port}/youtube?v=${vid}"
  [ "$mute" -eq 1 ] && page="${page}&mute=1"
elif [ "$mode" = "mobile" ]; then
  page="https://m.youtube.com/watch?v=${vid}&autoplay=1"
  [ "$mute" -eq 1 ] && page="${page}&mute=1"
elif [ "$mode" = "watch" ]; then
  page="https://www.youtube.com/watch?v=${vid}&autoplay=1"
  [ "$mute" -eq 1 ] && page="${page}&mute=1"
else
  page="https://www.youtube-nocookie.com/embed/${vid}?${embed_qs}"
fi
fi

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
CHR_PROFILE="${HOME}/.config/chromium-youtube-kiosk"
mkdir -p "$CHR_PROFILE"

echo "youtube-chromium: $page $(date)" >>"$LOG"
pkill -x chromium 2>/dev/null || true
pkill -f 'firefox-esr.*kiosk-profile' 2>/dev/null || true
sleep 1

CHR=chromium
command -v chromium >/dev/null 2>&1 || CHR=chromium-browser

CHR_EXTRA=()
# Pi 5 + X11 : watch.youtube = son sans image ; embed + GLES plus fiable.
read -r -a CHR_EXTRA <<<"${KIOSK_CHROMIUM_FLAGS:---ozone-platform=x11 --ignore-gpu-blocklist --use-gl=angle --use-angle=gl}"

nohup "$CHR" --user-data-dir="$CHR_PROFILE" --kiosk --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --disable-infobars --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 \
  "${CHR_EXTRA[@]}" "$page" </dev/null >>"$LOG" 2>&1 &

for _ in $(seq 1 20); do
  pgrep -x chromium >/dev/null 2>&1 && break
  sleep 1
done
pgrep -x chromium >/dev/null 2>&1 || exit 1

if command -v pactl >/dev/null 2>&1; then
  if [ "$mute" -eq 1 ]; then
    pactl set-sink-mute @DEFAULT_SINK@ 1 2>/dev/null || true
    echo "youtube-chromium: HDMI muet (son Bose) $(date)" >>"$LOG"
  else
    pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
  fi
fi

if command -v xdotool >/dev/null 2>&1; then
  sleep 2
  xdotool key --clearmodifiers space 2>/dev/null || true
fi
exit 0
