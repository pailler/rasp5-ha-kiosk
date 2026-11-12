#!/bin/bash
# Une seule instance Firefox (--no-remote) : onglet 1 = HA, onglet 2 réservé (about:blank).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
PROFILE="${HOME}/.mozilla/kiosk-profile"

pgrep -x firefox-esr >/dev/null || exit 1

/usr/bin/firefox-esr --profile "$PROFILE" -remote \
  'javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;var g=w.gBrowser;while(g.tabs.length<2)g.addTrustedTab("about:blank");if(g.tabs.length>2){while(g.tabs.length>2)g.removeTab(g.tabs[g.tabs.length-1]);}g.selectedTab=g.tabs[0];})();' \
  2>/dev/null || true
