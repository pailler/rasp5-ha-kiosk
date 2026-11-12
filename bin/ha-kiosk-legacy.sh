#!/bin/bash
# Mode d’origine : Firefox kiosk-profile, plein écran, authSig jeton long (ha-api-token).
set -euo pipefail
LOCK=/tmp/ha-kiosk-legacy.lock
if ! pgrep -f "ha-kiosk-legacy\\.sh" >/dev/null 2>&1 && ! pgrep -x firefox-esr >/dev/null 2>&1; then
  rm -f "$LOCK"
fi
exec 8>"$LOCK"
flock -n 8 || exit 0

. "$(dirname "$0")/kiosk-session-env.sh"
CONF="${HOME}/.config/ha-kiosk.env"
[ -r "$CONF" ] && . "$CONF"

FULLSCREEN_MODE="${KIOSK_FULLSCREEN:-fullscreen}"
# --kiosk : écran noir fréquent sur Pi 5 (Wayland ou X11) ; ignorer si KIOSK_ALLOW_KIOSK!=1
if [ "$FULLSCREEN_MODE" = "kiosk" ] && [ "${KIOSK_ALLOW_KIOSK:-0}" != "1" ]; then
  echo "KIOSK_FULLSCREEN=kiosk désactivé (écran noir) → fullscreen" >>"${HOME}/kiosk.log"
  FULLSCREEN_MODE=fullscreen
  KIOSK_FULLSCREEN=fullscreen
fi
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
PATH_VIEW="${KIOSK_LOVELACE_PATH:-/lovelace/dashboard-principal}"
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
mkdir -p "${HOME}/.cache"
printf '%s\n' "$URL" >"${HOME}/.cache/kiosk-last-ha-url"

PROFILE="${HOME}/.mozilla/kiosk-profile"
mkdir -p "$PROFILE"

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
  "${HOME}/bin/kiosk-wait-firefox-remote.sh" 45 2
}

load_second_tab_url() {
  local url="$1"
  [ -z "$url" ] && return 0
  wait_firefox_ready || return 1
  local js
  js="$(python3 - "$url" <<'PY'
import json, sys
u = json.dumps(sys.argv[1])
print(
    "javascript:(function(){"
    f"var u={u};"
    "var w=Services.wm.getMostRecentBrowserWindow();if(!w||!w.gBrowser)return;"
    "var g=w.gBrowser;"
    "while(g.tabs.length<2)g.addTrustedTab('about:blank');"
    "while(g.tabs.length>2)g.removeTab(g.tabs[g.tabs.length-1]);"
    "var t=g.tabs[1];"
    "t.linkedBrowser.loadURI(u,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});"
    "g.selectedTab=g.tabs[0];"
    "})();"
)
PY
)"
  "${HOME}/bin/kiosk-firefox-remote.sh" "$js" 2>/dev/null || true
  sleep 1
  focus_ha_tab
}

ensure_youtube_tab_slot() {
  wait_firefox_ready || return 0
  "${HOME}/bin/kiosk-ensure-two-tabs.sh" 2>/dev/null || true
  focus_ha_tab
}

if [ "${KIOSK_FORCE_RELAUNCH:-0}" != "1" ] && "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
  echo "Firefox actif — charge URL HA si vide $(date)" >>"$LOG"
  "${HOME}/bin/kiosk-ensure-ha-url.sh" 2>/dev/null || true
  [ -n "$SECOND_URL" ] && load_second_tab_url "$SECOND_URL"
  exit 0
fi

rm -f "$PROFILE"/sessionstore.json* "$PROFILE"/sessionCheckpoints.json "$PROFILE"/recovery.json 2>/dev/null || true
rm -rf "$PROFILE"/sessionstore-backups 2>/dev/null || true
mkdir -p "$PROFILE"/sessionstore-backups

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

pkill -f "firefox-esr.*kiosk-profile" 2>/dev/null || true
sleep 2
pgrep -f "firefox-esr.*kiosk-profile" >/dev/null 2>&1 && pkill -9 -f "firefox-esr.*kiosk-profile" 2>/dev/null || true
sleep 1
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

"${HOME}/bin/kiosk-prune-extra-firefox.sh" 2>/dev/null || true
if [ -x "${HOME}/bin/kiosk-firefox-launch-once.sh" ]; then
  "${HOME}/bin/kiosk-firefox-launch-once.sh" "${FF_CMD[@]}" "$URL" || true
else
  nohup "${FF_CMD[@]}" "$URL" </dev/null >>"$LOG" 2>&1 &
fi
if ! "${HOME}/bin/kiosk-wait-firefox-process.sh" 40 2; then
  if ! "${HOME}/bin/kiosk-firefox-kiosk-running.sh"; then
    echo "repli lancement Firefox direct $(date)" >>"$LOG"
    nohup "${FF_CMD[@]}" "$URL" </dev/null >>"$LOG" 2>&1 &
    "${HOME}/bin/kiosk-wait-firefox-process.sh" 30 2 || true
  fi
fi
sleep 5
pgrep -f hide-desktop-loop >/dev/null || "${HOME}/bin/hide-desktop-loop.sh" &

wait_firefox_ready || true

if [ -n "$SECOND_URL" ]; then
  load_second_tab_url "$SECOND_URL"
  echo "2e onglet (arrière-plan): $SECOND_URL" >>"$LOG"
else
  echo "boot: 1 seul onglet HA (onglet 2 à la demande YouTube)" >>"$LOG"
fi

"${HOME}/bin/kiosk-prune-extra-firefox.sh" 2>/dev/null || true
if [ "${KIOSK_APPLY_FULLSCREEN:-0}" = "1" ]; then
  "${HOME}/bin/kiosk-apply-fullscreen.sh" 2>/dev/null || true
fi
pgrep -af "firefox-esr.*kiosk-profile.*--no-remote" | head -1 >>"$LOG"
exit 0
