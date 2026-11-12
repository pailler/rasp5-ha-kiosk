#!/bin/bash
# Ouvre une URL dans l’onglet Firefox actif (barre d’adresse), sans -remote.
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
url="${1:-}"
[ -n "$url" ] || exit 1
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
if [ "${KIOSK_FIREFOX_WAYLAND:-0}" != "1" ]; then
  exec "${HOME}/bin/kiosk-xdotool-goto-url.sh" "$url"
fi
command -v wtype >/dev/null 2>&1 || exit 1
"${HOME}/bin/kiosk-focus-firefox-window.sh" 2>/dev/null || true
sleep 0.25
wtype -k F6 2>/dev/null || true
sleep 0.4
wtype -M ctrl -k a 2>/dev/null || true
sleep 0.08
wtype -P "$url" 2>/dev/null || true
sleep 0.08
wtype -k Return 2>/dev/null || true
exit 0
