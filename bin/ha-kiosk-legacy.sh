#!/bin/bash
# Mode d’origine : Firefox kiosk-profile, plein écran, authSig jeton long (ha-api-token).
set -euo pipefail
LOCK=/tmp/ha-kiosk-legacy.lock
exec 8>"$LOCK"
flock -n 8 || exit 0

. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

FULLSCREEN_MODE="${KIOSK_FULLSCREEN:-fullscreen}"
# kiosk + X11 : vrai plein écran (--kiosk Wayland = écran noir sur Pi 5)
if [ "$FULLSCREEN_MODE" = "kiosk" ] && [ "${KIOSK_KIOSK_USE_X11:-1}" = "1" ]; then
  KIOSK_FIREFOX_WAYLAND=0
fi

export DISPLAY="${DISPLAY:-:0}"
export GNOME_KEYRING_CONTROL=
export SECRET_SERVICE_DISABLE=1
export MOZ_DISABLE_RDD_SANDBOX=1

# Wayfire = session Wayland ; Firefox en XWayland casse scroll/zoom tactile.
KIOSK_FIREFOX_WAYLAND="${KIOSK_FIREFOX_WAYLAND:-1}"
if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ]; then
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
  export GDK_BACKEND=wayland
  unset MOZ_DISABLE_WAYLAND
  export MOZ_ENABLE_WAYLAND=1
else
  unset WAYLAND_DISPLAY
  export MOZ_DISABLE_WAYLAND=1
  export MOZ_USE_XINPUT2=1
fi

HA_BASE="${HA_URL:-http://192.168.1.51:8123}"
HA_BASE="${HA_BASE%/}"
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/ecranmural}"
SECOND_URL="${KIOSK_SECOND_URL:-}"
LOG="${HOME}/kiosk.log"

generate_ha_url() {
  local u try
  for try in 1 2 3 4 5; do
    u="$(KIOSK_USE_LEGACY_TOKEN=1 HA_URL="$HA_BASE" KIOSK_PATH="$PATH_VIEW" \
      python3 "${HOME}/bin/ha-kiosk-signed-url.py" 2>>"$LOG")" || u=""
    if [ -n "$u" ] && [[ "$u" == *authSig=* ]]; then
      echo "$u"
      return 0
    fi
    echo "authSig échec tentative $try" >>"$LOG"
    sleep 3
  done
  echo "${HA_BASE}${PATH_VIEW}"
}

URL="$(generate_ha_url)"

PROFILE="${HOME}/.mozilla/kiosk-profile"
mkdir -p "$PROFILE"
rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json "$PROFILE"/recovery.json 2>/dev/null || true
rm -rf "$PROFILE"/sessionstore-backups 2>/dev/null || true
mkdir -p "$PROFILE"/sessionstore-backups

firefox_focus_window() {
  local wid best="" area=0 w h a name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
    w=${WIDTH:-0}
    h=${HEIGHT:-0}
    a=$((w * h))
    echo "$name" | grep -qiE 'firefox|assistant|iahome|chargement' || continue
    [ "$a" -gt "$area" ] && area=$a && best=$wid
  done
  [ -n "$best" ] && xdotool windowactivate --sync "$best" 2>/dev/null
}

focus_ha_tab() {
  "${HOME}/bin/kiosk-focus-tab.sh" 1 2>/dev/null || {
    local _i
    for _i in 1 2; do
      firefox_focus_window 2>/dev/null || true
      sleep 0.5
      command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k 1 2>/dev/null || true
      sleep 0.4
    done
  }
}


wait_for_network() {
  local n=0
  while [ "$n" -lt 60 ]; do
    code_ha=$(curl -o /dev/null -sS --max-time 4 -w "%{http_code}" "${HA_BASE}/" 2>/dev/null) || code_ha=0
    case "$code_ha" in
      200|301|302|401|404) ;;
      *) n=$((n + 1)); sleep 2; continue ;;
    esac
    if [ -n "${SECOND_URL:-}" ]; then
      code_2=$(curl -o /dev/null -sS --max-time 6 -w "%{http_code}" "$SECOND_URL" 2>/dev/null) || code_2=0
      case "$code_2" in
        200|301|302|403) return 0 ;;
      esac
      n=$((n + 1)); sleep 2; continue
    fi
    return 0
  done
  return 1
}

wait_firefox_ready() {
  local i=0
  while [ "$i" -lt 45 ]; do
    if pgrep -x firefox-esr >/dev/null; then
      sleep 4
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  return 1
}

open_second_tab_background() {
  local url="$1"
  [ -z "$url" ] && return 0
  wait_firefox_ready || true
  firefox_focus_window 2>/dev/null || true
  if ! /usr/bin/firefox-esr --profile "$PROFILE" -remote "openURL(${url},new-background-tab)" 2>/dev/null; then
    /usr/bin/firefox-esr --profile "$PROFILE" -new-tab "$url" 2>/dev/null || true
  fi
  sleep 1
  focus_ha_tab
}

W=1920
H=1080
if [ "$KIOSK_FIREFOX_WAYLAND" != "1" ] && command -v xrandr >/dev/null 2>&1; then
  cur=$(xrandr 2>/dev/null | awk '/ connected /{f=1} f&&/\*/{print $1; exit}')
  if [ -n "$cur" ]; then
    W=${cur%x*}
    H=${cur#*x}
  fi
fi
"${HOME}/bin/kiosk-firefox-userjs.sh" "$PROFILE" "$URL"

if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ] && [ "$FULLSCREEN_MODE" = "fullscreen" ]; then
  "${HOME}/bin/kiosk-wayfire-window-rules.sh" 2>/dev/null || true
fi

wait_for_network || echo "réseau partiel (on lance quand même)" >>"$LOG"

pkill -9 -f firefox-esr 2>/dev/null || true
sleep 2
pkill -f firefox-geometry-guard 2>/dev/null || true
pkill -x onboard 2>/dev/null || true

echo "=== ha-kiosk-legacy $(date) wayland=$KIOSK_FIREFOX_WAYLAND === URL=$URL" >>"$LOG"

case "$FULLSCREEN_MODE" in
  kiosk)
    FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --kiosk)
    echo "lancement Firefox --kiosk (wayland=$KIOSK_FIREFOX_WAYLAND)" >>"$LOG"
    ;;
  f11)
    FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE")
    echo "lancement Firefox + F11 plein écran" >>"$LOG"
    ;;
  0)
    FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE")
    ;;
  *)
    FF_CMD=(/usr/bin/firefox-esr --no-remote --profile "$PROFILE" --start-maximized)
    echo "lancement Firefox start-maximized (Wayfire)" >>"$LOG"
    ;;
esac

"${FF_CMD[@]}" "$URL" &
if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ] && [ "$FULLSCREEN_MODE" != "0" ] && [ "$FULLSCREEN_MODE" != "kiosk" ]; then
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
fi

sleep 22
pgrep -f hide-desktop-loop >/dev/null || "${HOME}/bin/hide-desktop-loop.sh" &

if [ -n "$SECOND_URL" ]; then
  open_second_tab_background "$SECOND_URL"
  echo "2e onglet (arrière-plan): $SECOND_URL" >>"$LOG"
  focus_ha_tab
fi

if [ "$KIOSK_FIREFOX_WAYLAND" = "1" ]; then
  if [ "$FULLSCREEN_MODE" = "f11" ]; then
    i=0
    while [ "$i" -lt 12 ]; do
      sleep 2
      pgrep -x firefox-esr >/dev/null || break
      command -v wtype >/dev/null 2>&1 && wtype -k F11 2>/dev/null || true
      i=$((i + 1))
    done
    echo "plein écran F11 (Wayland) $(date)" >>"$LOG"
  fi
  pgrep -af "firefox-esr.*kiosk-profile" | head -1 >>"$LOG"
  exit 0
fi

pgrep -f firefox-geometry-guard >/dev/null || "${HOME}/bin/firefox-geometry-guard.sh" &

find_ha_window() {
  local wid name
  for wid in $(xdotool search --class firefox 2>/dev/null); do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    echo "$name" | grep -qiE 'home assistant|ecranmural|météo|meteo|mozilla firefox' && echo "$wid" && return 0
  done
  return 1
}

WID=""
for _ in $(seq 1 25); do
  WID=$(find_ha_window || true)
  [ -n "$WID" ] && break
  sleep 2
done
[ -z "$WID" ] && exit 1

for _ in 1 2 3 4 5; do
  xdotool windowmove --sync "$WID" 0 0 2>/dev/null || true
  xdotool windowsize --sync "$WID" "$W" "$H" 2>/dev/null || true
  if [ "$FULLSCREEN_MODE" = "f11" ]; then
    xdotool key --window "$WID" F11 2>/dev/null || true
  fi
  if [ "$FULLSCREEN_MODE" = "kiosk" ]; then
    break
  fi
  sleep 2
  eval "$(xdotool getwindowgeometry --shell "$WID" 2>/dev/null)"
  [ "${WIDTH:-0}" -ge "$((W - 20))" ] && [ "${HEIGHT:-0}" -ge "$((H - 20))" ] && break
done
xdotool windowactivate --sync "$WID" 2>/dev/null || true
if [ -n "$SECOND_URL" ]; then
  focus_ha_tab
fi

pgrep -af "firefox-esr.*8123" | head -1 >>"$LOG"
exit 0
