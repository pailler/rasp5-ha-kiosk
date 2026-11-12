#!/bin/bash
# Kiosque actif = au moins un Firefox principal kiosque.
"${HOME}/bin/kiosk-list-main-firefox.sh" 2>/dev/null | grep -q . && exit 0
pgrep -f "chromium.*8123" >/dev/null 2>&1 && exit 0
exit 1
