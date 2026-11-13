#!/bin/bash
# Navigateur kiosque HA actif (Firefox kiosk-profile ou Chromium chromium-ha-kiosk).
"${HOME}/bin/kiosk-list-main-firefox.sh" 2>/dev/null | grep -q . && exit 0
pgrep -f "chromium.*chromium-ha-kiosk" >/dev/null 2>&1 && exit 0
pgrep -f "chromium.*8123" >/dev/null 2>&1 && exit 0
exit 1
