#!/bin/bash
# Règles Wayfire : Firefox kiosque couvre tout l'écran (sans --kiosk ni F11).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"

CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
[ "${KIOSK_FIREFOX_WAYLAND:-1}" = "1" ] || exit 0
[ "${KIOSK_FULLSCREEN:-fullscreen}" = "0" ] && exit 0

WAYFIRE_INI="${HOME}/.config/wayfire.ini"
mkdir -p "${HOME}/.config"
touch "$WAYFIRE_INI"

MARK_BEGIN="# ha-kiosk-window-rules-begin"
MARK_END="# ha-kiosk-window-rules-end"

W="${KIOSK_SCREEN_W:-1920}"
H="${KIOSK_SCREEN_H:-1080}"

strip_old() {
  if grep -q "$MARK_BEGIN" "$WAYFIRE_INI" 2>/dev/null; then
    sed -i "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/d" "$WAYFIRE_INI"
  fi
}

strip_old

{
  echo ""
  echo "$MARK_BEGIN"
  echo "[window-rules]"
  echo "ha_kiosk_ff_max = on created if app_id contains \"firefox\" then maximize"
  echo "ha_kiosk_ff_geom = on created if app_id contains \"firefox\" then set geometry 0 0 ${W} ${H}"
  echo "ha_kiosk_ha_title = on created if title contains \"Home Assistant\" then maximize"
  echo "ha_kiosk_ha_geom = on created if title contains \"Home Assistant\" then set geometry 0 0 ${W} ${H}"
  echo "ha_kiosk_chr_max = on created if app_id contains \"chromium\" then maximize"
  echo "ha_kiosk_chr_geom = on created if app_id contains \"chromium\" then set geometry 0 0 ${W} ${H}"
  echo "$MARK_END"
} >>"$WAYFIRE_INI"

# Recharge la config Wayfire si possible (nouvelles règles sans redémarrer la session).
if pid=$(pgrep -x wayfire 2>/dev/null); then
  kill -HUP "$pid" 2>/dev/null || true
fi
