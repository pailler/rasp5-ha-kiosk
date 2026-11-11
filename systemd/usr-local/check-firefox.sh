#!/bin/bash
[ -f /home/rasp5/.kiosk-veille-active ] && exit 0
HOUR=$(date +%H); HOUR=$((10#$HOUR))
[ "$HOUR" -ge 1 ] && [ "$HOUR" -lt 7 ] && exit 0
pgrep -f "firefox-esr.*8123" >/dev/null 2>&1 && exit 0
logger "Kiosque HA absent - relance"
export DISPLAY="${DISPLAY:-:0}"
exec /home/rasp5/bin/ha-meteo-kiosk.sh
