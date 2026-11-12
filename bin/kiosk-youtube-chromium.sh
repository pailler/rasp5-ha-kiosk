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

port="${KIOSK_HTTP_PORT:-8765}"
page="http://127.0.0.1:${port}/youtube?v=${vid}"
[ "$mute" -eq 1 ] && page="${page}&mute=1"

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

nohup "$CHR" --user-data-dir="$CHR_PROFILE" --kiosk --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --disable-infobars --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 "$page" </dev/null >>"$LOG" 2>&1 &

for _ in $(seq 1 20); do
  pgrep -x chromium >/dev/null 2>&1 && exit 0
  pgrep -f "chromium.*youtube-nocookie" >/dev/null 2>&1 && exit 0
  sleep 1
done
exit 1
