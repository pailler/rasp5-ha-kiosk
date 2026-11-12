#!/bin/bash
# Affiche l’onglet N (1-based) dans Firefox kiosque — focus fenêtre + remote + raccourci.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"

TAB="${1:-2}"
PROFILE="${HOME}/.mozilla/kiosk-profile"
idx=$((TAB - 1))

pgrep -x firefox-esr >/dev/null || exit 1

firefox_focus_window() {
  command -v xdotool >/dev/null 2>&1 || return 1
  local wid name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name="$(xdotool getwindowname "$wid" 2>/dev/null)" || continue
    echo "$name" | grep -qiE 'firefox|youtube|assistant|iahome|mozilla' || continue
    xdotool windowactivate --sync "$wid" 2>/dev/null || xdotool windowactivate "$wid" 2>/dev/null || true
    return 0
  done
  return 1
}

firefox_remote() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 10 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
  else
    /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>/dev/null || true
  fi
}

firefox_focus_window || true

JS=$(
  python3 - "$idx" <<'PY'
import sys
i = int(sys.argv[1])
print(
    "javascript:(function(){"
    "try{Services.prefs.setBoolPref('browser.tabs.loadInBackground',false);"
    "Services.prefs.setBoolPref('browser.tabs.loadDivertedInBackground',false);}catch(e){}"
    "var w=Services.wm.getMostRecentBrowserWindow();"
    "if(!w)return;"
    "w.focus();"
    "var g=w.gBrowser;if(!g||!g.tabs.length)return;"
    f"var i={i};"
    "if(i<0||i>=g.tabs.length)return;"
    "var t=g.tabs[i];"
    "g.selectTabAtIndex(i);"
    "g.selectedTab=t;"
    "if(t.linkedBrowser)t.linkedBrowser.focus();"
    "})();"
)
PY
)

firefox_remote "$JS"
sleep 0.12
firefox_focus_window || true
if command -v wtype >/dev/null 2>&1; then
  wtype -M ctrl -k "$TAB" 2>/dev/null || true
fi
