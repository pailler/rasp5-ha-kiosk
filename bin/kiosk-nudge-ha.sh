#!/bin/bash
# Page blanche / onglet vide : un rechargement HA + focus (sans ouvrir une fenêtre).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
LOG="${HOME}/kiosk.log"
URL_FILE="${HOME}/.cache/kiosk-last-ha-url"

pgrep -x firefox-esr >/dev/null || exit 0
"${HOME}/bin/kiosk-firefox-kiosk-running.sh" || exit 0
[ -s "$URL_FILE" ] || exit 0
url=$(head -1 "$URL_FILE")

js=$(python3 - "$url" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    f"var want={u};"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;var t=g.tabs[0];if(!t)return;"
    "var cur=t.linkedBrowser.currentURI.spec;"
    "if(cur.indexOf('8123')>=0&&cur.indexOf('lovelace')>=0)return;"
    "if(cur==='about:blank'||cur.indexOf('8123')<0){"
    "t.linkedBrowser.loadURI(want,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "}"
    "g.selectedTab=t;w.focus();"
    "})();"
)
PY
)

"${HOME}/bin/kiosk-firefox-remote.sh" "$js" 2>/dev/null || true
"${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || true
echo "nudge-ha: reload si besoin $(date)" >>"$LOG"
