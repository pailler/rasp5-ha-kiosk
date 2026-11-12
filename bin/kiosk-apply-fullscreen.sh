#!/bin/bash
# Renforce le plein écran après boot (Wayfire ou mode --kiosk déjà actif).
set -euo pipefail
. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

MODE="${KIOSK_FULLSCREEN:-fullscreen}"
[ "${KIOSK_FIREFOX_WAYLAND:-1}" != "1" ] && exit 0
LOG="${HOME}/kiosk.log"

"${HOME}/bin/kiosk-wayfire-window-rules.sh" 2>/dev/null || true

firefox_focus_window() {
  local wid best="" area=0 w h a name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
    w=${WIDTH:-0}; h=${HEIGHT:-0}; a=$((w * h))
    echo "$name" | grep -qiE 'firefox|assistant|iahome|chargement' || continue
    [ "$a" -gt "$area" ] && area=$a && best=$wid
  done
  [ -n "$best" ] && xdotool windowactivate --sync "$best" 2>/dev/null
}

apply_maximize() {
  # Wayland natif : les règles Wayfire gèrent le maximize ; wtype reste un filet XWayland.
  firefox_focus_window 2>/dev/null || true
  sleep 0.4
  command -v wtype >/dev/null 2>&1 || return 0
  wtype -M super -k Up 2>/dev/null || wtype -M logo -k Up 2>/dev/null || true
}

apply_f11() {
  firefox_focus_window 2>/dev/null || true
  sleep 0.4
  command -v wtype >/dev/null 2>&1 && wtype -k F11 2>/dev/null || true
}

(
  for wait_s in 8 20 25; do
    sleep "$wait_s"
    pgrep -x firefox-esr >/dev/null || continue
    if pgrep -af 'firefox-esr.*--kiosk' >/dev/null 2>&1; then
      echo "plein écran (--kiosk) déjà actif $(date)" >>"$LOG"
      exit 0
    fi
    case "$MODE" in
      f11) apply_f11 ;;
      *) apply_maximize ;;
    esac
    echo "plein écran Wayfire (règles + maximize) $(date)" >>"$LOG"
  done
) &
