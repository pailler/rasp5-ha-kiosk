#!/bin/bash
# True seulement si le processus principal kiosque tourne (--no-remote).
pgrep -af 'firefox-esr.*kiosk-profile.*--no-remote' 2>/dev/null | grep -q .
