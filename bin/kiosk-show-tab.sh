#!/bin/bash
# Affiche l’onglet N dans l’instance Firefox déjà lancée (-remote uniquement).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"

TAB="${1:-2}"
PROFILE="${HOME}/.mozilla/kiosk-profile"
idx=$((TAB - 1))

pgrep -x firefox-esr >/dev/null || exit 1

if command -v xdotool >/dev/null 2>&1; then
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    xdotool windowactivate "$wid" 2>/dev/null && break
  done
fi

JS=$(
  python3 - "$idx" <<'PY'
import sys
i = int(sys.argv[1])
print(
    "javascript:(function(){"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "w.focus();"
    f"var i={i};"
    "var g=w.gBrowser;if(i<0||i>=g.tabs.length)return;"
    "g.selectTabAtIndex(i);"
    "g.selectedTab=g.tabs[i];"
    "})();"
)
PY
)

"${HOME}/bin/kiosk-firefox-remote.sh" "$JS" 2>/dev/null || true
command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k "$TAB" 2>/dev/null || true
