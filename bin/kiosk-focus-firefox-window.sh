#!/bin/bash
# Met la fenêtre Firefox au premier plan (xdotool / wtype, pas -remote).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
export DISPLAY="${DISPLAY:-:0}"
pgrep -x firefox-esr >/dev/null || exit 1
if command -v xdotool >/dev/null 2>&1; then
  wid="$(xdotool search --class firefox 2>/dev/null | head -1)"
  [ -n "$wid" ] && xdotool windowactivate "$wid" 2>/dev/null || true
fi
if [ "${KIOSK_NO_REMOTE:-1}" != "1" ]; then
  "${HOME}/bin/kiosk-firefox-remote.sh" \
    'javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w)w.focus();})();' \
    2>/dev/null || true
fi
