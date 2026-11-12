#!/bin/bash
# Un seul onglet Home Assistant + plein écran Wayfire, puis redémarrage.
set -euo pipefail
CONF="${HOME}/.config/ha-kiosk.env"
mkdir -p "${HOME}/.config"
touch "$CONF"
if grep -q '^KIOSK_SECOND_URL=' "$CONF" 2>/dev/null; then
  sed -i 's/^KIOSK_SECOND_URL=.*/KIOSK_SECOND_URL=/' "$CONF"
else
  echo 'KIOSK_SECOND_URL=' >>"$CONF"
fi
grep -q '^KIOSK_FULLSCREEN=' "$CONF" && sed -i 's/^KIOSK_FULLSCREEN=.*/KIOSK_FULLSCREEN=kiosk/' "$CONF" \
  || echo 'KIOSK_FULLSCREEN=kiosk' >>"$CONF"
grep -q '^KIOSK_KIOSK_USE_X11=' "$CONF" || echo 'KIOSK_KIOSK_USE_X11=1' >>"$CONF"
grep -q '^KIOSK_LEGACY=' "$CONF" || echo 'KIOSK_LEGACY=1' >>"$CONF"
grep -q '^KIOSK_FIREFOX_WAYLAND=' "$CONF" || echo 'KIOSK_FIREFOX_WAYLAND=1' >>"$CONF"
echo "Config: $(grep -E 'KIOSK_SECOND_URL|KIOSK_FULLSCREEN' "$CONF")"
sudo reboot
