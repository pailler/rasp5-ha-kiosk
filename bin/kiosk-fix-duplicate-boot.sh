#!/bin/bash
# Évite start-kiosk-boot en double (lxsession + systemd).
set -euo pipefail
AUTOSTART="${HOME}/.config/lxsession/LXDE-pi/autostart"
HAS_LX=0
if [ -f "$AUTOSTART" ] && grep -q 'start-kiosk-boot' "$AUTOSTART" 2>/dev/null; then
  HAS_LX=1
fi
HAS_UNIT=0
systemctl --user is-enabled ha-kiosk-boot.service >/dev/null 2>&1 && HAS_UNIT=1

if [ "$HAS_LX" = "1" ] && [ "$HAS_UNIT" = "1" ]; then
  echo "Double boot détecté : désactivation de ha-kiosk-boot.service (lxsession garde start-kiosk-boot)"
  systemctl --user disable --now ha-kiosk-boot.service 2>/dev/null || true
elif [ "$HAS_LX" = "0" ] && [ "$HAS_UNIT" = "0" ]; then
  echo "Aucun boot auto : active ha-kiosk-boot.service"
  systemctl --user enable --now ha-kiosk-boot.service 2>/dev/null || true
else
  echo "Boot kiosque : une seule source OK (lx=$HAS_LX unit=$HAS_UNIT)"
fi
