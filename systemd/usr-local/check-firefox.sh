#!/bin/bash
KIOSK_USER="${KIOSK_USER:-rasp5}"
KIOSK_HOME="/home/${KIOSK_USER}"
KIOSK_UID="$(id -u "${KIOSK_USER}" 2>/dev/null || echo 1000)"

[ -f "${KIOSK_HOME}/.kiosk-veille-active" ] && exit 0
HOUR=$(date +%H); HOUR=$((10#$HOUR))
[ "$HOUR" -ge 1 ] && [ "$HOUR" -lt 7 ] && exit 0
[ -f /tmp/ha-kiosk-legacy.lock ] && exit 0
pgrep -u "${KIOSK_USER}" -f start-kiosk-boot\\.sh >/dev/null 2>&1 && exit 0
pgrep -u "${KIOSK_USER}" -f ha-kiosk-legacy\\.sh >/dev/null 2>&1 && exit 0
uptime_s=$(awk '{print int($1)}' /proc/uptime)
[ "$uptime_s" -lt 1200 ] && exit 0
STAMP="/run/user/${KIOSK_UID}/kiosk-boot-once"
[ ! -f "$STAMP" ] && exit 0
ff_n=$(pgrep -u "${KIOSK_USER}" -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | wc -l)
[ "$ff_n" -gt 1 ] && runuser -u "${KIOSK_USER}" -- "${KIOSK_HOME}/bin/kiosk-prune-extra-firefox.sh" && exit 0
pgrep -u "${KIOSK_USER}" -x firefox-esr >/dev/null 2>&1 && exit 0
pgrep -u "${KIOSK_USER}" -f ha-kiosk-legacy >/dev/null 2>&1 && exit 0
logger "Kiosque HA absent - relance (user ${KIOSK_USER})"
exec runuser -u "${KIOSK_USER}" -- env \
  DISPLAY=:0 \
  XDG_RUNTIME_DIR="/run/user/${KIOSK_UID}" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${KIOSK_UID}/bus" \
  "${KIOSK_HOME}/bin/kiosk-launch.sh"
