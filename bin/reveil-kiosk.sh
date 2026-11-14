#!/bin/bash
LOG="${HOME}/veille.log"
# shellcheck source=kiosk-session-env.sh
. "${HOME}/bin/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

{
  echo "=== reveil-kiosk $(date) ==="
  export DISPLAY="${DISPLAY:-:0}"
  xset -q >/dev/null 2>&1 || echo "avertissement: X11 unreachable (DISPLAY=$DISPLAY)"
  "${HOME}/bin/kiosk-display-wake.sh" 2>/dev/null || true

  systemctl --user start hide-desktop.service firefox-geometry-guard.service 2>/dev/null || true

  ok=0
  PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}"
  if [ "${KIOSK_HA_USE_CHROMIUM:-0}" = "1" ]; then
    export KIOSK_LAUNCH_WAIT=1
    if KIOSK_LAUNCH_WAIT=1 "${HOME}/bin/kiosk-return-ha.sh" "$PATH_VIEW"; then
      ok=1
    fi
  elif "${HOME}/bin/kiosk-launch.sh"; then
    ok=1
  elif "${HOME}/bin/kiosk-ha-browser-active.sh"; then
    ok=1
  fi
  if [ "$ok" -eq 1 ]; then
    rm -f "${HOME}/.kiosk-veille-active"
    rm -f "${HOME}/.kiosk-veille-night"
    for _ in 1 2 3 4 5 6 8 10; do
      "${HOME}/bin/kiosk-ha-browser-active.sh" 2>/dev/null && break
      sleep 1
    done
    if ! "${HOME}/bin/kiosk-ha-browser-active.sh" 2>/dev/null && [ "${KIOSK_HA_USE_CHROMIUM:-0}" = "1" ]; then
      echo "avertissement: kiosque HA absent après lancement → nouvel essai return-ha"
      "${HOME}/bin/kiosk-return-ha.sh" "${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}" || true
      sleep 3
    fi
    if "${HOME}/bin/kiosk-ha-browser-active.sh" 2>/dev/null; then
      echo "réveil OK kiosque HA actif ($(pgrep -af 'chromium.*8123' 2>/dev/null | head -1))"
    else
      echo "réveil partiel (navigateur kiosque non détecté)"
    fi
  else
    echo "ÉCHEC kiosk-launch → on garde le flag veille"
    touch "${HOME}/.kiosk-veille-active"
    exit 1
  fi
} >>"$LOG" 2>&1
