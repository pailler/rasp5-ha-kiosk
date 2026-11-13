#!/bin/bash
# shellcheck source=kiosk-session-env.sh
. "$(dirname "$0")/kiosk-session-env.sh"
# Veille : absent (traceur routeur / WiFi) OU nuit 01h-07h.
# Délais (secondes) : KIOSK_VEILLE_DELAY_SEC (défaut 300), KIOSK_REVEIL_DELAY_SEC (défaut 120).
HA_URL="${HA_URL:-http://192.168.1.51:8123}"
# Traceur LAN (WiFi) : quitte "home" dès déconnexion du routeur. Éviter le GPS seul (ex. device_tracker.mi).
ENTITY="${HA_ENTITY:-device_tracker.xiaomi_13_lite}"
TOKEN_FILE="${HOME}/.config/ha-api-token"
CONF_FILE="${HOME}/.config/ha-kiosk.env"
TZ_NAME="${TZ:-Europe/Paris}"
LOG="${HOME}/veille-watch.log"
VEILLE_DELAY="${KIOSK_VEILLE_DELAY_SEC:-300}"
REVEIL_DELAY="${KIOSK_REVEIL_DELAY_SEC:-120}"
STATE_FILE="${HOME}/.veille-watch-state"
FAIL_FILE="${HOME}/.veille-watch-fail-count"

[ -r "$CONF_FILE" ] && . "$CONF_FILE"

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

fail_count() {
  [ -f "$FAIL_FILE" ] && cat "$FAIL_FILE" || echo 0
}
save_fail_count() { echo "$1" >"$FAIL_FILE"; }

load_since
now=$(date +%s)
in_veille=0
[ -f "${HOME}/.kiosk-veille-active" ] && in_veille=1

state=$(phone_state)
if [ -z "$state" ]; then
  fc=$(fail_count)
  fc=$((fc + 1))
  save_fail_count "$fc"
  echo "$(date) lecture HA échouée (tentative $fc, entité=$ENTITY)" >>"$LOG"
  # Pas de réseau vers HA : veille après 5 min de polls ratés (évite écran bloqué)
  if [ "$in_veille" -eq 0 ] && [ "$fc" -ge 5 ]; then
    SINCE=${VEILLE_FAIL_SINCE:-0}
    [ ! -f "${HOME}/.veille-fail-since" ] && echo "$now" >"${HOME}/.veille-fail-since"
    since=$(cat "${HOME}/.veille-fail-since" 2>/dev/null || echo "$now")
    if [ $((now - since)) -ge "$VEILLE_DELAY" ]; then
      "${HOME}/bin/veille-ram.sh"
      save_since "$now" "veille"
      save_fail_count 0
      rm -f "${HOME}/.veille-fail-since"
      echo "$(date) veille active (HA injoignable $fc fois)" >>"$LOG"
    fi
  fi
  exit 0
fi

save_fail_count 0
rm -f "${HOME}/.veille-fail-since"

want=idle
if should_veille "$state"; then
  want=veille
elif [ "$in_veille" -eq 1 ] && should_reveil "$state"; then
  want=reveil
fi

if [ "$MODE" != "$want" ]; then
  SINCE=$now
  MODE=$want
  save_since "$SINCE" "$MODE"
  echo "$(date) entity=$ENTITY state=$state want=$want (nouveau)" >>"$LOG"
fi

elapsed=$((now - SINCE))
need_delay=$VEILLE_DELAY
case "$want" in
  reveil) need_delay=$REVEIL_DELAY ;;
  veille) need_delay=$VEILLE_DELAY ;;
esac
[ "$elapsed" -lt "$need_delay" ] && exit 0

if [ "$want" = veille ] && [ "$in_veille" -eq 0 ]; then
  "${HOME}/bin/veille-ram.sh"
  save_since "$now" "veille"
  echo "$(date) veille active (tel=$state)" >>"$LOG"
elif [ "$want" = reveil ] && [ "$in_veille" -eq 1 ]; then
  "${HOME}/bin/reveil-kiosk.sh"
  save_since "$now" "reveil"
  echo "$(date) reveil (tel=$state)" >>"$LOG"
fi
