#!/bin/bash
# YouTube dans l’onglet 2 du même Firefox (--no-remote principal, pas de 2ᵉ processus).
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

pgrep -x firefox-esr >/dev/null || { echo "Firefox inactif" >>"$LOG"; exit 1; }

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

"${HOME}/bin/kiosk-ensure-two-tabs.sh" 2>/dev/null || true

firefox_remote() {
  timeout 12 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
}

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

ok=0
out="$(firefox_remote "$(load_js)")"
if [ -n "$out" ] && ! echo "$out" | grep -qiE 'failed|error|cannot|not running'; then
  ok=1
fi

if [ "$ok" -eq 0 ]; then
  echo "remote JS onglet2: ${out:-vide}" >>"$LOG"
  out="$(firefox_remote "openURL(${URL})")"
  echo "remote openURL: ${out:-vide}" >>"$LOG"
fi

sleep 0.4
"${HOME}/bin/kiosk-show-tab.sh" 2 2>/dev/null || true
sleep 0.25
"${HOME}/bin/kiosk-show-tab.sh" 2 2>/dev/null || true

if [ "${KIOSK_MUTE_LOCAL:-0}" = "1" ] && command -v pactl >/dev/null 2>&1; then
  pactl set-sink-mute @DEFAULT_SINK@ 1 2>/dev/null || true
  echo "audio local Pi coupé (Bose)" >>"$LOG"
fi

echo "onglet 2 YouTube: $URL ($(date))" >>"$LOG"
exit 0
