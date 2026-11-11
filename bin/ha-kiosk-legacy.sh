#!/bin/bash
# Mode d’origine : Firefox kiosk-profile, plein écran F11, authSig jeton long (ha-api-token).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

export DISPLAY="${DISPLAY:-:0}"
unset WAYLAND_DISPLAY
export MOZ_DISABLE_WAYLAND=1
export MOZ_DISABLE_RDD_SANDBOX=1
export GNOME_KEYRING_CONTROL=
export SECRET_SERVICE_DISABLE=1

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}"

URL="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
  python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>/dev/null)" || URL="${HA_BASE}${PATH_VIEW}"

PROFILE="${HOME}/.mozilla/kiosk-profile"
mkdir -p "$PROFILE"
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json 2>/dev/null || true

pkill -9 -f firefox-esr 2>/dev/null || true
sleep 2
pkill -x onboard 2>/dev/null || true

LOG="${HOME}/kiosk.log"
echo "=== ha-kiosk-legacy $(date) === URL=$URL" >>"$LOG"
/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized "$URL" &

sleep 12
for _ in $(seq 1 15); do
  WID=$(xdotool search --class firefox 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  sleep 2
done
[ -z "${WID:-}" ] && exit 1

xdotool windowactivate --sync "$WID" 2>/dev/null || true
xdotool windowmove --sync "$WID" 0 0 2>/dev/null || true
xdotool windowsize --sync "$WID" 1920 1080 2>/dev/null || true
xdotool key --window "$WID" F11 2>/dev/null || true
pgrep -af "firefox-esr.*8123" | head -1 >>"$LOG"
exit 0
