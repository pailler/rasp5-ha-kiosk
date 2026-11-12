#!/bin/bash
# Charge une URL (Firefox HA) ou YouTube via Chromium.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
url="${1:-}"
[ -n "$url" ] || exit 1

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

KIOSK_YOUTUBE_USE_CHROMIUM="${KIOSK_YOUTUBE_USE_CHROMIUM:-1}"
is_youtube=0
case "$url" in
  *youtube.com*|*youtu.be*|*mural-youtube-embed*|*youtube-nocookie*|file://*/kiosk-youtube-page.html*)
    is_youtube=1
    ;;
  */youtube?*|*/youtube\?*)
    is_youtube=1
    ;;
esac

if [ "$is_youtube" -eq 1 ] && [ "$KIOSK_YOUTUBE_USE_CHROMIUM" = "1" ]; then
  if "${HOME}/bin/kiosk-youtube-chromium.sh" "$url"; then
    exit 0
  fi
  echo "goto-url: Chromium échec, repli Firefox $(date)" >>"$LOG"
fi

# Retour HA : fermer Chromium
if [[ "$url" == *lovelace* ]] || [[ "$url" == *8123* && "$url" != *youtube* && "$url" != *mural-youtube* ]]; then
  pkill -x chromium 2>/dev/null || true
  sleep 0.5
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
  pgrep -x firefox-esr >/dev/null && exit 0
  sleep 1
done
exit 1
