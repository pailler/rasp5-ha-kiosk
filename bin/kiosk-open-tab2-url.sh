#!/bin/bash
# Ouvre une URL YouTube dans l’onglet 2 Firefox kiosque et affiche cet onglet.
set -uo pipefail
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

firefox_focus_window() {
  if ! command -v xdotool >/dev/null 2>&1; then
    return 1
  fi
  local wid name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name="$(xdotool getwindowname "$wid" 2>/dev/null)" || continue
    echo "$name" | grep -qiE 'firefox|youtube|assistant|iahome|chargement|mozilla' || continue
    xdotool windowactivate "$wid" 2>/dev/null || true
    sleep 0.15
    return 0
  done
  return 1
}

remote_ok() {
  local msg="$1"
  [ -n "$msg" ] && ! echo "$msg" | grep -qiE 'failed|error|cannot|mozilla is not running'
}

firefox_remote() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 12 /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
  else
    /usr/bin/firefox-esr --profile "$PROFILE" -remote "$1" 2>&1 || true
  fi
}

load_in_tab2_js() {
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
    "w.focus();"
    "if(t.linkedBrowser)t.linkedBrowser.focus();"
    "})();"
)
PY
}

opened=0
firefox_focus_window || true

firefox_remote "javascript:(function(){try{Services.prefs.setBoolPref('browser.tabs.loadInBackground',false);Services.prefs.setBoolPref('browser.tabs.loadDivertedInBackground',false);}catch(e){}})();" >/dev/null 2>&1 || true

out="$(firefox_remote "$(load_in_tab2_js)")"
if remote_ok "$out"; then
  opened=1
fi

if [ "$opened" -eq 0 ]; then
  echo "remote JS échec ($out), repli openURL/new-tab" >>"$LOG"
  out="$(firefox_remote "openURL(${URL},new-tab)")"
  if remote_ok "$out"; then
    opened=1
    firefox_remote "javascript:(function(){var w=Services.wm.getMostRecentBrowserWindow();if(w&&w.gBrowser&&w.gBrowser.tabs.length>=2)w.gBrowser.selectedTab=w.gBrowser.tabs[1];})();" >/dev/null 2>&1 || true
  fi
fi

if [ "$opened" -eq 0 ]; then
  /usr/bin/firefox-esr --profile "$PROFILE" -new-tab "$URL" 2>/dev/null || \
    /usr/bin/firefox-esr --profile "$PROFILE" "$URL" 2>/dev/null || true
  sleep 0.8
  opened=1
fi

SHOW_TAB="${HOME}/bin/kiosk-show-tab.sh"
if [ -x "$SHOW_TAB" ]; then
  for _ in 1 2 3 4 5 6; do
  "$SHOW_TAB" 2
    sleep 0.35
  done
else
  firefox_focus_window || true
  if command -v wtype >/dev/null 2>&1; then
    for _ in 1 2 3; do
      wtype -M ctrl -k 2 2>/dev/null || true
      sleep 0.2
    done
  fi
fi

set_local_mute() {
  if ! command -v pactl >/dev/null 2>&1; then
    return 0
  fi
  pactl set-sink-mute @DEFAULT_SINK@ "$1" 2>/dev/null || true
}

if [ "${KIOSK_MUTE_LOCAL:-0}" = "1" ]; then
  set_local_mute 1
  echo "audio local Pi coupé (Bose)" >>"$LOG"
fi

echo "onglet 2 YouTube: $URL ($(date))" >>"$LOG"
