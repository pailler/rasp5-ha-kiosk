#!/bin/bash
# Onglet vide / about:blank : charge l’URL HA signée (authSig) dans l’onglet existant.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
URL_FILE="${HOME}/.cache/kiosk-last-ha-url"
HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}"

"${HOME}/bin/kiosk-firefox-kiosk-running.sh" || exit 1

url=""
for try in 1 2 3; do
  url="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
    python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || url=""
  [[ "$url" == *authSig=* ]] && break
  sleep 2
done
[ -z "$url" ] && [ -s "$URL_FILE" ] && url="$(head -1 "$URL_FILE")"
[ -z "$url" ] && url="${HA_BASE}${PATH_VIEW}"
printf '%s\n' "$url" >"$URL_FILE"

"${HOME}/bin/kiosk-wait-firefox-remote.sh" 30 1 >/dev/null 2>&1 || true

js="$(python3 - "$url" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    f"var want={u};"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;var t=g.selectedTab||g.tabs[0];if(!t)return;"
    "var cur='';try{cur=t.linkedBrowser.currentURI.spec;}catch(e){}"
    "if(cur.indexOf('lovelace')>=0&&cur.indexOf('8123')>=0)return;"
    "try{"
    "var uri=Services.io.newURI(want,null,t.linkedBrowser.currentURI);"
    "t.linkedBrowser.loadURI(uri,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "g.selectedTab=t;w.focus();"
    "}catch(e){}"
    "})();"
)
PY
)"

if "${HOME}/bin/kiosk-firefox-remote.sh" "$js" 2>/dev/null; then
  echo "ensure-ha-url: remote OK $(date)" >>"$LOG"
  exit 0
fi

if command -v wtype >/dev/null 2>&1; then
  "${HOME}/bin/kiosk-focus-firefox-window.sh" 2>/dev/null || true
  sleep 0.2
  wtype -k F6 2>/dev/null || true
  sleep 0.35
  wtype -M ctrl -k a 2>/dev/null || true
  sleep 0.1
  wtype -P "$url" 2>/dev/null || true
  sleep 0.1
  wtype -k Return 2>/dev/null || true
  echo "ensure-ha-url: wtype $(date)" >>"$LOG"
  exit 0
fi

echo "ensure-ha-url: échec $(date)" >>"$LOG"
exit 1
