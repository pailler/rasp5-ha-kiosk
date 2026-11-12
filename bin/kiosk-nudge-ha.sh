#!/bin/bash
# Page blanche : charge l’URL HA (délègue à ensure-ha-url, sans -remote).
set -uo pipefail
exec "${HOME}/bin/kiosk-ensure-ha-url.sh"
