#!/bin/bash
# Charge une URL : relance Firefox kiosque (fiable sur Pi 5, pas de xdotool/-remote).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
url="${1:-}"
[ -n "$url" ] || exit 1

case "$url" in
  *youtube.com*|*youtu.be*|*mural-youtube-embed*)
    if file_url="$("${HOME}/bin/kiosk-youtube-fullpage-html.sh" "$url" 2>/dev/null)"; then
      url="$file_url"
      echo "goto-url: page locale iframe $(date)" >>"$LOG"
    fi
    ;;
esac

if [ "${KIOSK_YOUTUBE_USE_CHROMIUM:-0}" = "1" ] && command -v chromium >/dev/null 2>&1 \
  && [[ "${1:-}" == *youtube* || "${1:-}" == *youtu.be* ]]; then
  export DISPLAY="${DISPLAY:-:0}"
  export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
  pkill -x chromium 2>/dev/null || true
  sleep 1
  CHR_PROFILE="${HOME}/.config/chromium-youtube-kiosk"
  mkdir -p "$CHR_PROFILE"
  nohup chromium --user-data-dir="$CHR_PROFILE" --kiosk --no-first-run --no-default-browser-check \
    --disable-session-crashed-bubble --autoplay-policy=no-user-gesture-required \
    "${1}" </dev/null >>"$LOG" 2>&1 &
  sleep 3
  pgrep -x chromium >/dev/null && exit 0
fi

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
echo "goto-url: relance Firefox → $url $(date)" >>"$LOG"
"${HOME}/bin/kiosk-firefox-userjs.sh" "$PROFILE" "" 2>/dev/null || true
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json "$PROFILE"/recovery.json 2>/dev/null || true
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
