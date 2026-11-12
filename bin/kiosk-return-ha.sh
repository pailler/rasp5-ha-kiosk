#!/bin/bash
# Retour mur → Firefox propre (comme ha-kiosk-legacy), après Chromium YouTube.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
PATH_VIEW="${1:-${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}}"
case "$PATH_VIEW" in
  /*) ;;
  *) PATH_VIEW="/${PATH_VIEW}" ;;
esac

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
export MOZ_DISABLE_RDD_SANDBOX=1
export GNOME_KEYRING_CONTROL=
export SECRET_SERVICE_DISABLE=1
if [ "${KIOSK_FIREFOX_WAYLAND:-0}" = "1" ]; then
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
  export GDK_BACKEND=wayland
  export MOZ_ENABLE_WAYLAND=1
else
  unset WAYLAND_DISPLAY
  export MOZ_DISABLE_WAYLAND=1
  export MOZ_USE_XINPUT2=1
fi

pkill -x chromium 2>/dev/null || true
pkill -9 -f 'firefox-esr.*kiosk-profile' 2>/dev/null || pkill -9 -x firefox-esr 2>/dev/null || true
sleep 2
pgrep -x firefox-esr >/dev/null 2>&1 && pkill -9 -x firefox-esr 2>/dev/null || true
sleep 1
"${HOME}/bin/kiosk-prune-extra-firefox.sh" 2>/dev/null || true
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true

url=""
for try in 1 2 3 4 5; do
  url="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
    python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || url=""
  [[ "$url" == *authSig=* ]] && break
  sleep 2
done
[ -z "$url" ] && url="${HA_BASE}${PATH_VIEW}"
printf '%s\n' "$url" >"${HOME}/.cache/kiosk-last-ha-url"

PROFILE="${HOME}/.mozilla/kiosk-profile"
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json "$PROFILE"/recovery.json 2>/dev/null || true
rm -rf "$PROFILE"/sessionstore-backups 2>/dev/null || true
mkdir -p "$PROFILE"/sessionstore-backups

export KIOSK_LOVELACE_PATH="$PATH_VIEW"
"${HOME}/bin/kiosk-firefox-userjs.sh" "$PROFILE" "$url"
rm -f /tmp/kiosk-firefox-launch.lock /tmp/ha-kiosk-legacy.lock /tmp/kiosk-lovelace-nudge.count

echo "return-ha: $PATH_VIEW $(date)" >>"$LOG"
FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized)
if [ -x "${HOME}/bin/kiosk-firefox-launch-once.sh" ]; then
  "${HOME}/bin/kiosk-firefox-launch-once.sh" "${FF_CMD[@]}" "$url" || true
else
  nohup "${FF_CMD[@]}" "$url" </dev/null >>"$LOG" 2>&1 &
fi
"${HOME}/bin/kiosk-wait-firefox-process.sh" 45 2 >/dev/null || true
sleep 6
"${HOME}/bin/kiosk-focus-firefox-window.sh" 2>/dev/null || true
if [ "${KIOSK_APPLY_FULLSCREEN:-0}" = "1" ]; then
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
fi
"${HOME}/bin/kiosk-lovelace-nudge.sh" 2>/dev/null || true
echo "return-ha: firefox OK $(date)" >>"$LOG"
