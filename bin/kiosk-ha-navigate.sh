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

if ! "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
  if ! pgrep -x firefox-esr >/dev/null; then
    echo "navigate: pas de Firefox $(date)" >>"$LOG"
    exit 1
  fi
  echo "navigate: Firefox sans profil kiosque détecté, on continue $(date)" >>"$LOG"
fi

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

if [ "${KIOSK_NO_REMOTE:-1}" != "1" ] && "${HOME}/bin/kiosk-firefox-remote.sh" "$js"; then
  echo "navigate: ${PATH_REL} $(date)" >>"$LOG"
  exit 0
fi

if "${HOME}/bin/kiosk-wtype-goto-url.sh" "$target"; then
  echo "navigate (wtype): ${PATH_REL} $(date)" >>"$LOG"
  exit 0
fi

echo "navigate échec: ${PATH_REL} $(date)" >>"$LOG"
exit 1
