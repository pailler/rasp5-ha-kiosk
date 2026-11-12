#!/bin/bash
# Charge une URL dans Firefox kiosque (rechargement onglet ou relance propre).
set -uo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
LOG="${HOME}/kiosk.log"
url="${1:-}"
[ -n "$url" ] || exit 1

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

if "${HOME}/bin/kiosk-firefox-kiosk-running.sh" || pgrep -x firefox-esr >/dev/null; then
  if [ "${KIOSK_FIREFOX_WAYLAND:-0}" != "1" ]; then
    if "${HOME}/bin/kiosk-xdotool-goto-url.sh" "$url" 2>/dev/null; then
      echo "goto-url: xdotool OK $(date)" >>"$LOG"
      exit 0
    fi
  else
    if command -v wtype >/dev/null 2>&1 && "${HOME}/bin/kiosk-wtype-goto-url.sh" "$url" 2>/dev/null; then
      echo "goto-url: wtype OK $(date)" >>"$LOG"
      exit 0
    fi
  fi
fi

PROFILE="${HOME}/.mozilla/kiosk-profile"
echo "goto-url: relance Firefox → $url $(date)" >>"$LOG"
pkill -f 'firefox-esr.*kiosk-profile' 2>/dev/null || true
sleep 2
rm -f /tmp/kiosk-firefox-launch.lock /tmp/ha-kiosk-legacy.lock
nohup /usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized "$url" \
  </dev/null >>"$LOG" 2>&1 &
sleep 2
pgrep -x firefox-esr >/dev/null && exit 0
exit 1
