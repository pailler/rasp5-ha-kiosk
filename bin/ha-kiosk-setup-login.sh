#!/bin/bash
# Crée ~/.config/ha-kiosk-login si absent (à compléter avec le vrai mot de passe).
set -euo pipefail
DEST="${HOME}/.config/ha-kiosk-login"
install -d -m 700 "${HOME}/.config"
if [ -f "$DEST" ]; then
  echo "Déjà présent: $DEST (chmod 600 recommandé)"
  exit 0
fi
cat >"$DEST" <<'EOF'
# Compte Home Assistant pour le kiosque (mode kiosque HACS : utilisateur Kiosk conseillé)
KIOSK_USER=Kiosk
KIOSK_PASSWORD=CHANGEME
EOF
chmod 600 "$DEST"
echo "Créé $DEST → éditez:  nano $DEST"
echo "Puis:  DISPLAY=:0 $HOME/bin/ha-kiosk-oauth-login.py"
echo "       DISPLAY=:0 $HOME/bin/ha-meteo-kiosk.sh"
