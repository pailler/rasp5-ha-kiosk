#!/bin/bash
# Navigation Lovelace dans le même onglet Firefox (pas d’onglet 2).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

PATH_REL="${1:-}"
LOG="${HOME}/kiosk.log"
HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"

[ -n "$PATH_REL" ] || { echo "usage: $0 /lovelace/..." >&2; exit 1; }
case "$PATH_REL" in
  /*) ;;
  *) PATH_REL="/${PATH_REL}" ;;
esac

"${HOME}/bin/kiosk-firefox-kiosk-running.sh" || exit 1

target="${HA_BASE}${PATH_REL}"
js="$(python3 - "$target" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "var t=w.gBrowser.selectedTab||w.gBrowser.tabs[0];if(!t)return;"
    f"var target={u};"
    "try{"
    "var uri=Services.io.newURI(target,null,t.linkedBrowser.currentURI);"
    "t.linkedBrowser.loadURI(uri,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "w.focus();"
    "}catch(e){}"
    "})();"
)
PY
)"

if "${HOME}/bin/kiosk-firefox-remote.sh" "$js"; then
  echo "navigate: ${PATH_REL} $(date)" >>"$LOG"
  exit 0
fi

if command -v wtype >/dev/null 2>&1; then
  "${HOME}/bin/kiosk-focus-firefox-window.sh" 2>/dev/null || true
  wtype -k F6 2>/dev/null || true
  sleep 0.35
  wtype -M ctrl -k a 2>/dev/null || true
  sleep 0.1
  wtype -P "$target" 2>/dev/null || true
  sleep 0.1
  wtype -k Return 2>/dev/null || true
  echo "navigate (wtype): ${PATH_REL} $(date)" >>"$LOG"
  exit 0
fi

echo "navigate échec: ${PATH_REL} $(date)" >>"$LOG"
exit 1
