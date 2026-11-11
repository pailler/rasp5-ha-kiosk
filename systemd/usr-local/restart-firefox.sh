#!/bin/bash
[ -f /home/rasp5/.kiosk-veille-active ] && exit 0
HOUR=$(date +%H); HOUR=$((10#$HOUR))
[ "$HOUR" -ge 1 ] && [ "$HOUR" -lt 7 ] && exit 0
export DISPLAY="${DISPLAY:-:0}"
exec /home/rasp5/bin/ha-meteo-kiosk.sh
