#!/bin/bash
# Ouvre une URL YouTube dans l’onglet 2 Firefox kiosque et affiche cet onglet.
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

URL="${1:-}"
LOG="${HOME}/kiosk.log"
PROFILE="${HOME}/.mozilla/kiosk-profile"

[ -n "$URL" ] || { echo "usage: $0 <url>" >&2; exit 1; }

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

pgrep -x firefox-esr >/dev/null || { echo "Firefox inactif" >&2; exit 1; }

if ! python3 - "$URL" <<'PY'
import re, sys
url = sys.argv[1]
if not re.match(r"^https?://([a-z0-9-]+\.)?(youtube\.com|youtu\.be)/", url, re.I):
    sys.exit(2)
if re.search(r"youtube\.com/watch", url, re.I) and "v=" not in url and "list=" not in url:
    sys.exit(3)
PY
then
  echo "URL YouTube invalide ou incomplète (ajoutez v= ou list=)" >&2
  exit 2
fi

remote_ok() {
  local msg="$1"
  [ -n "$msg" ] && ! echo "$msg" | grep -qiE 'failed|error|cannot'
}

firefox_remote() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 8 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
  else
    /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
  fi
}

# 1) Charger YouTube dans l’onglet 2 (pas un nouvel onglet 3+)
JS_LOAD=$(
  python3 - "$URL" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    f"var u={u};"
    "var w=Services.wm.getMostRecentBrowserWindow();"
    "if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;"
    "while(g.tabs.length<2)g.addTrustedTab('about:blank');"
    "var t=g.tabs[1];"
    "t.linkedBrowser.loadURI(u,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "g.selectedTab=t;"
    "})();"
)
PY
)

out="$(firefox_remote "$JS_LOAD" || true)"
if ! remote_ok "$out"; then
  echo "remote JS échec, repli openURL" >>"$LOG"
  out="$(firefox_remote "openURL(${URL},new-tab)" || true)"
  if ! remote_ok "$out"; then
    /usr/bin/firefox-esr --profile "$PROFILE" -new-tab "$URL" 2>/dev/null || true
  fi
  sleep 0.6
  firefox_remote "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs[1])w.gBrowser.selectedTab=w.gBrowser.tabs[1];})();" >/dev/null 2>&1 || true
fi

sleep 0.4
if command -v wtype >/dev/null 2>&1; then
  for _ in 1 2; do
    wtype -M ctrl -k 2 2>/dev/null || true
    sleep 0.25
  done
fi

echo "onglet 2 YouTube: $URL ($(date))" >>"$LOG"
