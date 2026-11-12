#!/bin/bash
# Met la fenêtre Firefox au premier plan (Wayland / -remote).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
PROFILE="${HOME}/.mozilla/kiosk-profile"
pgrep -x firefox-esr >/dev/null || exit 1
"${HOME}/bin/kiosk-wait-firefox-remote.sh" 8 1 2>/dev/null || exit 1
/usr/bin/firefox-esr --profile "$PROFILE" -remote \
  'javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w)w.focus();})();' \
  2>/dev/null || true
