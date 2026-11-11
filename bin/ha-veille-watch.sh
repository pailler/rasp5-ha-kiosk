#!/bin/bash
# Veille RAM : absent (device_tracker) OU nuit 01h-07h, délai 5 min.
HA_URL="${HA_URL:-http://192.168.1.51:8123}"
ENTITY="${HA_ENTITY:-device_tracker.mi}"
TOKEN_FILE="${HOME}/.config/ha-api-token"
TZ_NAME="${TZ:-Europe/Paris}"
LOG="${HOME}/veille-watch.log"
DELAY=300
STATE_FILE="${HOME}/.veille-watch-state"

if [ ! -r "$TOKEN_FILE" ]; then
  echo "Token HA manquant: $TOKEN_FILE" >>"$LOG"
  exit 1
fi
TOKEN=$(tr -d '\r\n' <"$TOKEN_FILE")

phone_state() {
  curl -fsS -m 8 -H "Authorization: Bearer $TOKEN" \
    "$HA_URL/api/states/$ENTITY" | sed -n 's/.*"state"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

is_night() {
  local h
  h=$(TZ="$TZ_NAME" date +%H)
  h=${h#0}; h=$((10#$h))
  [ "$h" -ge 1 ] && [ "$h" -lt 7 ]
}

should_veille() {
  local s="$1"
  is_night && return 0
  case "$s" in
    not_home|unavailable|unknown) return 0 ;;
  esac
  return 1
}

should_reveil() {
  local s="$1"
  is_night && return 1
  [ "$s" = "home" ] && return 0
  return 1
}

load_since() { [ -f "$STATE_FILE" ] && . "$STATE_FILE"; SINCE=${SINCE:-0}; MODE=${MODE:-}; }
save_since() { printf 'SINCE=%s\nMODE=%s\n' "$1" "$2" >"$STATE_FILE"; }

load_since
now=$(date +%s)

state=$(phone_state)
if [ -z "$state" ]; then
  echo "$(date) lecture HA échouée" >>"$LOG"
  exit 0
fi

want=idle
if should_veille "$state"; then want=veille; fi
if should_reveil "$state"; then want=reveil; fi

if [ "$MODE" != "$want" ]; then
  SINCE=$now
  MODE=$want
  save_since "$SINCE" "$MODE"
  echo "$(date) state=$state want=$want (nouveau)" >>"$LOG"
fi

elapsed=$((now - SINCE))
[ "$elapsed" -lt "$DELAY" ] && exit 0

in_veille=0
[ -f "${HOME}/.kiosk-veille-active" ] && in_veille=1

if [ "$want" = veille ] && [ "$in_veille" -eq 0 ]; then
  "${HOME}/bin/veille-ram.sh"
  save_since "$now" "veille"
  echo "$(date) veille active (tel=$state)" >>"$LOG"
elif [ "$want" = reveil ] && [ "$in_veille" -eq 1 ]; then
  "${HOME}/bin/reveil-kiosk.sh"
  save_since "$now" "reveil"
  echo "$(date) reveil (tel=$state)" >>"$LOG"
fi
