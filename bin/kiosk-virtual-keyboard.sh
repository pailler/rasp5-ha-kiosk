#!/bin/bash
# Clavier virtuel tactile (saisie dans Lovelace / formulaires hors login auto).
. "$(dirname "$0")/kiosk-session-env.sh"
export GTK_IM_MODULE="${GTK_IM_MODULE:-onboard}"
export QT_IM_MODULE="${QT_IM_MODULE:-onboard}"
export XMODIFIERS="${XMODIFIERS:-@im=onboard}"

if command -v onboard >/dev/null 2>&1; then
  if ! pgrep -x onboard >/dev/null 2>&1; then
  onboard --layout=Compact --theme=DarkBoard &
    sleep 1
  fi
  gsettings set org.onboard.onboard auto-show true 2>/dev/null || true
  gsettings set org.onboard.onboard xembed-onboard true 2>/dev/null || true
  exit 0
fi

if command -v squeekboard >/dev/null 2>&1; then
  pgrep -f squeekboard >/dev/null 2>&1 || squeekboard &
  exit 0
fi

if command -v matchbox-keyboard >/dev/null 2>&1; then
  pgrep -f matchbox-keyboard >/dev/null 2>&1 || matchbox-keyboard &
  exit 0
fi

exit 0
