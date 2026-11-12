#!/bin/bash
# True si une instance Firefox utilise le profil kiosque (--no-remote).
pgrep -af 'firefox-esr.*kiosk-profile' 2>/dev/null | grep -q .
