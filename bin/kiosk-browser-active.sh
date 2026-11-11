#!/bin/bash
# Navigateur kiosque démarré (HA direct, page kiosk-start.html, ou Chromium).
if pgrep -x firefox-esr >/dev/null 2>&1; then
  pgrep -af "firefox-esr.*(kiosk-profile|kiosk-start|8123)" >/dev/null 2>&1 && exit 0
fi
pgrep -f "chromium.*8123" >/dev/null 2>&1 && exit 0
exit 1
