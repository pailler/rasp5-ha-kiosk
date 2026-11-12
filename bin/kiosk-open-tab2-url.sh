#!/bin/bash
# YouTube → onglet 2 du même Firefox (instance --no-remote). Aucune nouvelle fenêtre.
set -uo pipefail
exec 8>/tmp/kiosk-open-tab2.lock
flock -n 8 || { echo "open-tab2 déjà en cours" >&2; exit 0; }
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

URL="${1:-}"
LOG="${HOME}/kiosk.log"
PROFILE="${HOME}/.mozilla/kiosk-profile"

[ -n "$URL" ] || { echo "usage: $0 <url>" >&2; exit 1; }

# Une seule fenêtre navigateur kiosque
ff_main=$(pgrep -ox firefox-esr 2>/dev/null || true)
if [ -z "$ff_main" ]; then
  echo "Firefox inactif" >>"$LOG"
  exit 1
fi

if ! python3 - "$URL" <<'PY'
import re, sys
url = sys.argv[1]
if not re.match(r"^https?://([a-z0-9-]+\.)?(youtube\.com|youtu\.be)/", url, re.I):
    sys.exit(2)
if re.search(r"youtube\.com/watch", url, re.I) and "v=" not in url and "list=" not in url:
    sys.exit(3)
PY
then
  echo "URL YouTube invalide" >>"$LOG"
  exit 2
fi

firefox_remote() {
  timeout 12 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
}

firefox_remote 'javascript:(function(){var wm=Services.wm;var keep=wm.getMostRecentBrowserWindow();var e=wm.getEnumerator("navigator:browser");while(e.hasMoreElements()){var w=e.getNext();if(w!==keep)try{w.close();}catch(x){}}})();'

"${HOME}/bin/kiosk-ensure-two-tabs.sh" 2>/dev/null || true

load_js() {
  python3 - "$URL" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    "try{Services.prefs.setBoolPref('browser.tabs.loadInBackground',false);"
    "Services.prefs.setBoolPref('browser.tabs.loadDivertedInBackground',false);}catch(e){}"
    f"var u={u};"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;"
    "while(g.tabs.length<2)g.addTrustedTab('about:blank');"
    "while(g.tabs.length>2)g.removeTab(g.tabs[g.tabs.length-1]);"
    "var t=g.tabs[1];"
    "t.linkedBrowser.loadURI(u,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "g.selectTabAtIndex(1);"
    "g.selectedTab=t;"
    "w.focus();"
    "})();"
)
PY
}

out="$(firefox_remote "$(load_js)")"
if echo "$out" | grep -qiE 'failed|error|cannot|not running'; then
  echo "onglet2 remote échec (pas de repli fenêtre): ${out:-vide}" >>"$LOG"
  exit 1
fi

sleep 0.35
"${HOME}/bin/kiosk-show-tab.sh" 2 2>/dev/null || true

if [ "${KIOSK_MUTE_LOCAL:-0}" = "1" ] && command -v pactl >/dev/null 2>&1; then
  pactl set-sink-mute @DEFAULT_SINK@ 1 2>/dev/null || true
  echo "audio local Pi coupé (Bose)" >>"$LOG"
fi

echo "onglet 2 YouTube: $URL ($(date))" >>"$LOG"
exit 0
