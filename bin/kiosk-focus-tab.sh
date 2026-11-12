#!/bin/bash
# Focus onglet Firefox kiosque (Wayland : wtype seul ne suffit pas toujours).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

TAB="${1:-2}"
PROFILE="${HOME}/.mozilla/kiosk-profile"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

pgrep -x firefox-esr >/dev/null || exit 1

switch_to_url() {
  local url="$1"
  [ -z "$url" ] && return 1
  /usr/bin/firefox-esr --profile "$PROFILE" "$url" 2>/dev/null
}

case "$TAB" in
  1)
    url="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="${HA_URL:-http://192.168.1.51:8123}" \
      KIOSK_PATH="${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}" \
      python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>/dev/null)" || true
    if [ -n "$url" ] && switch_to_url "$url"; then exit 0; fi
    ;;
  2)
    if [ -n "${KIOSK_SECOND_URL:-}" ] && switch_to_url "$KIOSK_SECOND_URL"; then
      exit 0
    fi
    ;;
esac

idx=$((TAB - 1))
/usr/bin/firefox-esr --profile "$PROFILE" -remote \
  "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[${idx}])w.gBrowser.selectTabAtIndex(${idx});})();" 2>/dev/null && exit 0

command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k "$TAB" 2>/dev/null || true
