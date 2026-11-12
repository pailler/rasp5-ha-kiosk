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
    "${HOME}/bin/kiosk-firefox-remote.sh" \
      "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[0])w.gBrowser.selectedTab=w.gBrowser.tabs[0];})();" 2>/dev/null || true
    command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k 1 2>/dev/null || true
    if command -v pactl >/dev/null 2>&1; then
      pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
    fi
    exit 0
    ;;
  2) ;;
esac

if [ -x "${HOME}/bin/kiosk-show-tab.sh" ]; then
  exec "${HOME}/bin/kiosk-show-tab.sh" "$TAB"
fi

idx=$((TAB - 1))
"${HOME}/bin/kiosk-firefox-remote.sh" \
  "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[${idx}])w.gBrowser.selectTabAtIndex(${idx});})();" 2>/dev/null && exit 0

command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k "$TAB" 2>/dev/null || true
