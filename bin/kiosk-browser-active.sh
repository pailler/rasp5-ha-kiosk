#!/bin/bash
# Kiosque actif si Firefox ESR tourne (legacy) ou Chromium sur HA.
pgrep -x firefox-esr >/dev/null 2>&1 && exit 0
pgrep -f "chromium.*8123" >/dev/null 2>&1 && exit 0
exit 1
