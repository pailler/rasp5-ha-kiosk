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

case "$TAB" in
  1)
    /usr/bin/firefox-esr --profile "$PROFILE" -remote \
      "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[0])w.gBrowser.selectedTab=w.gBrowser.tabs[0];})();" 2>/dev/null || true
    command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k 1 2>/dev/null || true
    exit 0
    ;;
  2)
    if [ -n "${KIOSK_SECOND_URL:-}" ]; then
      "${HOME}/bin/kiosk-open-tab2-url.sh" "$KIOSK_SECOND_URL" 2>/dev/null && exit 0
    fi
    ;;
esac

idx=$((TAB - 1))
/usr/bin/firefox-esr --profile "$PROFILE" -remote \
  "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[${idx}])w.gBrowser.selectTabAtIndex(${idx});})();" 2>/dev/null && exit 0

command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k "$TAB" 2>/dev/null || true
